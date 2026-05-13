
from pymongo import MongoClient

# 1. Connect Database
db_client = MongoClient("mongodb://localhost:27017/")
db = db_client["foodieai_db"] 
recipes_collection = db["recipes"]

# 2. The Deterministic Knowledge Base
ALLERGEN_MAP = {
    "dairy": ["dairy", "milk", "butter", "cheese", "cream", "whey", "yogurt", "ghee", "parmesan"],
    "gluten": ["gluten", "wheat", "flour", "barley", "rye", "bread", "pasta", "soy sauce"],
    "nut": ["nut", "peanut", "almond", "walnut", "pecan", "cashew", "pistachio", "macadamia"],
    "shellfish": ["shellfish", "shrimp", "crab", "lobster", "prawn", "oyster", "clam"],
    "soy": ["soy", "edamame", "tofu", "tempeh", "miso", "soy sauce"], 
    "egg": ["egg", "yolk", "albumen", "mayo", "meringue"], 
    "sesame": ["sesame", "tahini", "hummus"] 
}

DIET_RESTRICTIONS = {
    "vegan": ["meat", "beef", "pork", "chicken", "poultry", "fish", "shellfish", "dairy", "milk", "cheese", "butter", "egg", "honey", "gelatin", "whey"],
    "vegetarian": ["meat", "beef", "pork", "chicken", "poultry", "fish", "shellfish", "gelatin", "broth"],
    "pescatarian": ["meat", "beef", "pork", "chicken", "poultry", "gelatin"],
    "keto": ["sugar", "flour", "bread", "pasta", "rice", "potato", "honey", "syrup", "corn", "oats"],
    "halal": ["pork", "bacon", "ham", "alcohol", "wine", "beer", "gelatin", "rum", "bourbon", "vodka"],
    "paleo": ["sugar", "dairy", "cheese", "milk", "wheat", "corn", "beans", "lentils", "peanut"],
}

MEDICAL_RESTRICTIONS = {
    "diabetes": ["sugar", "honey", "syrup", "molasses", "caramel", "soda", "sweetened"],
    "hypertension": ["salt", "msg", "soy sauce", "bacon", "sausage", "ham"],
    "celiac": ["gluten", "wheat", "flour", "barley", "rye", "bread", "pasta"],
    "high cholesterol": ["butter", "bacon", "sausage", "cream", "cheese", "beef", "pork", "fried"],
    "ibs": ["garlic", "onion", "beans", "lentils", "cabbage", "broccoli", "cauliflower", "dairy"] 
}

CUISINE_MAP = {
    "chinese": ["chinese", "stir fry", "soy sauce", "hoisin", "szechuan", "dim sum", "dumpling"],
    "mexican": ["mexican", "taco", "burrito", "enchilada", "fajita", "tortilla", "salsa", "jalapeno", "poblano"],
    "italian": ["italian", "pasta", "spaghetti", "pizza", "risotto", "ravioli", "gnocchi"],
    "indian": ["indian", "curry", "masala", "tikka", "tandoori", "cumin", "turmeric"],
    "thai": ["thai", "pad thai", "curry paste", "lemongrass", "galangal", "fish sauce", "coconut milk"],
    "french": ["french", "butter", "wine", "crepe", "baguette", "brie", "camembert"]
}

def clean_and_tag_database():
    print("🧹 Wiping old AI tags AND legacy schema fields (allergenTags, dietTags)...")
    
    # THE FIX: This instantly deletes all three fields from the entire database
    recipes_collection.update_many({}, {
        "$unset": {
            "ai_tags": "",
            "allergenTags": "",
            "dietTags": ""
        }
    })
    
    # Grab all recipes to apply the fresh tags
    recipes = list(recipes_collection.find({}))
    print(f"Found {len(recipes)} recipes. Running Deterministic Overwrite...\n")

    for recipe in recipes:
        name = recipe.get("recipe_name", "")
        raw_ingredients = recipe.get("ingredients", [])
        ingredients_str = " ".join([i.lower() for i in raw_ingredients])
        search_text = (name + " " + ingredients_str).lower()

        # Build the exact JSON structure
        new_tags = {
            "contains_allergens": [k for k, v in ALLERGEN_MAP.items() if any(word in search_text for word in v)],
            "violates_diets": [k for k, v in DIET_RESTRICTIONS.items() if any(word in search_text for word in v)],
            "violates_medical": [k for k, v in MEDICAL_RESTRICTIONS.items() if any(word in search_text for word in v)],
            "cuisine_type": [k for k, v in CUISINE_MAP.items() if any(word in search_text for word in v)]
        }

        # Save the perfect local tags
        recipes_collection.update_one(
            {"_id": recipe["_id"]},
            {"$set": {"ai_tags": new_tags}}
        )
        
    print(f"✅ Successfully cleaned out the garbage and tagged all {len(recipes)} recipes! Your schema is now flawless.")

if __name__ == "__main__":
    clean_and_tag_database()