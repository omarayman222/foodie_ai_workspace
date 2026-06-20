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

STAPLES = ["salt", "pepper", "water", "oil", "olive oil", "butter", "sugar"]


def _recipe_to_dict(recipe, extra=None):
    """Convert a MongoDB recipe doc to the full dict Flutter expects."""
    d = {
        "_id": str(recipe.get("_id", "")),
        "recipe_name": recipe.get("recipe_name", "Unknown Recipe"),
        "img_src": recipe.get("img_src", ""),
        "url": recipe.get("url", ""),
        "ingredients": recipe.get("ingredients", []),
        "directions": recipe.get("directions", ""),
        "prep_time": recipe.get("prep_time", ""),
        "cook_time": recipe.get("cook_time", ""),
        "total_time": recipe.get("total_time", ""),
        "servings": str(recipe.get("servings", "")),
        "nutrition": recipe.get("nutrition", ""),
        "cuisine_path": recipe.get("cuisine_path", ""),
        "rating": recipe.get("rating", 0) or 0,
    }
    if extra:
        d.update(extra)
    return d


def is_recipe_safe(recipe, user_allergies, user_diets, user_medical):
    allergies = [a.lower() for a in user_allergies]
    diets = [d.lower() for d in user_diets]
    medical = [m.lower() for m in user_medical]

    recipe_allergens = [a.lower() for a in recipe.get("contains_allergens", [])]
    recipe_violations = [m.lower() for m in recipe.get("violates_medical", [])]

    for violation in recipe_violations:
        if any(violation in m for m in medical) or any(violation in a for a in allergies):
            return False

    for allergen in recipe_allergens:
        if any(allergen in a for a in allergies):
            return False

    if "gluten-free" in diets and "gluten" in recipe_allergens:
        return False

    if "vegan" in diets and ("dairy" in recipe_allergens or "eggs" in recipe_allergens or "meat" in recipe_allergens):
        return False

    return True


def get_smart_recommendations(
    user_ingredients: list[str],
    user_allergies: list[str],
    user_diets: list[str],
    medical_conditions: list[str],
    dislikes: list[str],
    disliked_cuisines: list[str],
    top_n: int = 14,
):
    # Fetch all recipes (ingredient_vector kept for scoring, _id included)
    all_recipes = list(recipes_collection.find({}))

    # Phase 1: safety filter
    safe_recipes = [
        r for r in all_recipes
        if is_recipe_safe(r, user_allergies, user_diets, medical_conditions)
    ]

    # Dislike filter (ingredient text + disliked cuisines)
    clean_dislikes = [d.lower().strip() for d in dislikes]
    clean_disliked_cuisines = [c.lower().strip() for c in disliked_cuisines]

    def passes_dislikes(recipe):
        ing_text = " ".join(i.lower() for i in recipe.get("ingredients", []))
        if any(d in ing_text for d in clean_dislikes):
            return False
        cuisine = (recipe.get("cuisine_path") or "").lower()
        if any(c in cuisine for c in clean_disliked_cuisines):
            return False
        return True

    safe_recipes = [r for r in safe_recipes if passes_dislikes(r)]

    # Empty pantry — return top safe recipes with full data
    if not user_ingredients:
        print("Empty pantry detected! Returning default safe recommendations.")
        return [_recipe_to_dict(r) for r in safe_recipes[:top_n]]

    # Phase 2: hybrid vector matching
    if not safe_recipes:
        return []

    pantry_text = ", ".join(user_ingredients).lower()
    user_vector = model.encode(pantry_text)
    user_item_vectors = model.encode(user_ingredients)

    scored_recipes = []

    for recipe in safe_recipes:
        recipe_vector = recipe.get("ingredient_vector")
        if not recipe_vector:
            continue

        similarity_score = util.cos_sim(user_vector, recipe_vector).item()
        base_percentage = min(similarity_score * 120, 100.0)

        if base_percentage < 30.0:
            continue

        raw_ingredients = recipe.get("ingredients", [])
        clean_ingredients = [
            ing for ing in raw_ingredients
            if ing.lower().strip() not in JUNK_FRAGMENTS and len(ing.strip()) > 1
        ]

        matched_items = []
        missing_items = []

        if clean_ingredients:
            recipe_ing_vectors = model.encode(clean_ingredients)
            for idx, ing in enumerate(clean_ingredients):
                clean_ing_lower = ing.lower()
                if any(u_ing in clean_ing_lower for u_ing in user_ingredients):
                    matched_items.append(ing)
                    continue
                sim_matrix = util.cos_sim(recipe_ing_vectors[idx], user_item_vectors)
                if sim_matrix.max().item() >= 0.50:
                    matched_items.append(ing)
                else:
                    missing_items.append(ing)

        if not matched_items:
            continue

        core_missing_count = sum(
            1 for m in missing_items
            if not any(staple in m.lower() for staple in STAPLES)
        )
        penalty = min(core_missing_count * 8.0, 40.0)
        final_match_percentage = max(base_percentage - penalty, 0.0)

        if final_match_percentage > 15.0:
            scored_recipes.append(_recipe_to_dict(recipe, {
                "match_percentage": round(final_match_percentage, 1),
                "matched_ingredients": matched_items,
                "missing_ingredients": missing_items,
            }))

    scored_recipes.sort(key=lambda x: x["match_percentage"], reverse=True)
    return scored_recipes[:top_n]
