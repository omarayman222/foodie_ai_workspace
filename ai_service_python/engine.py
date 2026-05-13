from database import recipes_collection
from sentence_transformers import SentenceTransformer, util

print("Loading NLP Model for Engine...")
model = SentenceTransformer('all-MiniLM-L6-v2')

JUNK_FRAGMENTS = {
    "for garnish", "to taste", "divided", "optional", "chopped", 
    "diced", "minced", "sliced", "drained", "rinsed", "softened", 
    "melted", "to serve", "as needed", "room temperature", "beaten",
    "crushed", "halved", "garnish", "separated", "if desired"
}

# The Staples list stays here, because it's used for the missing ingredient penalty!
STAPLES = ["salt", "pepper", "water", "oil", "olive oil", "butter", "sugar"]


def is_recipe_safe(recipe, user_allergies, user_diets, user_medical):
    # 1. Normalize everything to lowercase for safe matching
    allergies = [a.lower() for a in user_allergies]
    diets = [d.lower() for d in user_diets]
    medical = [m.lower() for m in user_medical]
    
    # Safely get recipe arrays (assuming recipe is a dictionary)
    recipe_allergens = [a.lower() for a in recipe.get("contains_allergens", [])]
    recipe_violations = [m.lower() for m in recipe.get("violates_medical", [])]

    # 2. Check Medical Violations (Substring matching)
    # This catches "celiac" (recipe) inside "celiac disease" (user)
    for violation in recipe_violations:
        if any(violation in m for m in medical) or any(violation in a for a in allergies):
            return False

    # 3. Check Standard Allergies
    for allergen in recipe_allergens:
        if any(allergen in a for a in allergies):
            return False

    # 4. Hardcoded Safety Bridges (Diet constraints)
    if "gluten-free" in diets and "gluten" in recipe_allergens:
        return False
    
    if "vegan" in diets and ("dairy" in recipe_allergens or "eggs" in recipe_allergens or "meat" in recipe_allergens):
        return False

    # If it passed all tests, it is safe to eat!
    return True


def get_smart_recommendations(user_ingredients: list[str], user_allergies: list[str], user_diets: list[str], medical_conditions: list[str], dislikes: list[str], disliked_cuisines: list[str]):
    
    # --- PHASE 1: THE GENAI TAG FILTER ---
    all_recipes = list(recipes_collection.find({}, {"_id": 0})) 
    safe_recipes = []
    
    # Clean the explicit dislikes so we can string-match them later
    clean_dislikes = [d.lower().strip() for d in dislikes]
    
    for recipe in all_recipes:
        tags = recipe.get("ai_tags", {})
        recipe_ingredients_str = " ".join([i.lower() for i in recipe.get("ingredients", [])])
        
        # 1. Check AI Tags
        has_allergy = any(a.lower() in [tag.lower() for tag in tags.get("contains_allergens", [])] for a in user_allergies)
        breaks_diet = any(d.lower() in [tag.lower() for tag in tags.get("violates_diets", [])] for d in user_diets)
        breaks_medical = any(m.lower() in [tag.lower() for tag in tags.get("violates_medical", [])] for m in medical_conditions)
        bad_cuisine = any(c.lower() in [tag.lower() for tag in tags.get("cuisine_type", [])] for c in disliked_cuisines)
        
        # 2. Check explicit ingredient dislikes (literal string match)
        has_disliked_ingredient = any(dislike in recipe_ingredients_str for dislike in clean_dislikes)
        
        # If it passes all 5 safety checks, it survives Phase 1!
        if not (has_allergy or breaks_diet or breaks_medical or bad_cuisine or has_disliked_ingredient):
            safe_recipes.append(recipe)
    safe_recipes = []
    for recipe in all_recipes:
        if is_recipe_safe(recipe, user_allergies, user_diets, medical_conditions):
            safe_recipes.append(recipe)

    if not user_ingredients or len(user_ingredients) == 0:
        print("Empty pantry detected! Returning default safe recommendations.")
        # Return the top 10 safe recipes (or however your data is formatted)
        return safe_recipes[:10]
    
   # --- PHASE 2: HYBRID VECTOR AI MATCHING ---
    if not safe_recipes:
        return []

    # 1. Vectorize the whole pantry for the overall score
    pantry_text = ", ".join(user_ingredients).lower()
    user_vector = model.encode(pantry_text)
    
    # THE FIX PART 1: Vectorize individual pantry items for the UI arrays
    user_item_vectors = model.encode(user_ingredients)

    scored_recipes = []
    
    for recipe in safe_recipes:
        recipe_vector = recipe.get("ingredient_vector")
        if not recipe_vector:
            continue 

        # 2. Get the overall mathematical semantic score
        similarity_score = util.cos_sim(user_vector, recipe_vector).item()
        base_percentage = min(similarity_score * 120, 100.0) 
        
        # CPU OPTIMIZATION: Only do heavy ingredient sorting if the recipe is actually decent
        if base_percentage < 30.0:
            continue
        
        raw_ingredients = recipe.get("ingredients", [])
        clean_ingredients = []
        
        for ing in raw_ingredients:
            clean_ing = ing.lower().strip()
            if clean_ing not in JUNK_FRAGMENTS and len(clean_ing) > 1:
                clean_ingredients.append(ing)

        matched_items = []
        missing_items = []

# 3. THE FIX PART 2: Vector-Based UI Sorting (With Literal Fallback)
        if len(clean_ingredients) > 0:
            recipe_ing_vectors = model.encode(clean_ingredients)
            
            for idx, ing in enumerate(clean_ingredients):
                clean_ing_lower = ing.lower()
                
                # BUG 1 FIX: Common Sense String Check First
                if any(u_ing in clean_ing_lower for u_ing in user_ingredients):
                    matched_items.append(ing)
                    continue # It's a match! Skip the heavy AI math.
                
                # If exact text fails, ask the AI for synonyms (lowered threshold slightly)
                sim_matrix = util.cos_sim(recipe_ing_vectors[idx], user_item_vectors)
                best_match_score = sim_matrix.max().item()
                
                if best_match_score >= 0.50:
                    matched_items.append(ing)
                else:
                    missing_items.append(ing)

        # BUG 2 FIX: The Zero-Match Bouncer
        # If we didn't match a single ingredient, throw the recipe away immediately.
        if len(matched_items) == 0:
            continue

        # 4. Calculate the Core Ingredient Penalty 
        core_missing_count = 0
        for missing in missing_items:
            if not any(staple in missing.lower() for staple in STAPLES):
                core_missing_count += 1
                
        penalty = min(core_missing_count * 8.0, 40.0) 
        final_match_percentage = max(base_percentage - penalty, 0.0) 

        # Lower the survival threshold slightly so 1-ingredient pantries still get ideas
        if final_match_percentage > 15.0:
            scored_recipes.append({
                "recipe_name": recipe.get("recipe_name", "Unknown Recipe"),
                "match_percentage": round(final_match_percentage, 1),
                "matched_ingredients": matched_items, 
                "missing_ingredients": missing_items, 
                "img_src": recipe.get("img_src", ""),
                "url": recipe.get("url", "")
            })
    
    scored_recipes.sort(key=lambda x: x["match_percentage"], reverse=True)
    return scored_recipes[:5]