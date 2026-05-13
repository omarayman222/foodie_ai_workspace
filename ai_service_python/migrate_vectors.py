from pymongo import MongoClient
from sentence_transformers import SentenceTransformer
import time

# 1. Connect to Database
client = MongoClient("mongodb://localhost:27017/")
db = client["foodieai_db"]
recipes_collection = db["recipes"]

# 2. Load the AI Model
print("Downloading/Loading AI Model... This might take a minute.")
model = SentenceTransformer('all-MiniLM-L6-v2')
print("Model loaded successfully! 🧠")

# 3. Fetch all recipes
recipes = list(recipes_collection.find({}))
print(f"Found {len(recipes)} recipes. Starting vectorization...")

updated_count = 0
start_time = time.time()

# 4. The Mathematical Conversion
for recipe in recipes:
    # Skip if already vectorized (saves time if you run it twice)
    if "ingredient_vector" in recipe:
        continue
        
    raw_ingredients = recipe.get("ingredients", [])
    
    # Combine ingredients into a single descriptive sentence
    ingredient_text = ", ".join(raw_ingredients).lower()
    
    # Convert the text into a vector (a list of floats)
    vector = model.encode(ingredient_text).tolist()
    
    # Save the new vector field back to MongoDB
    recipes_collection.update_one(
        {"_id": recipe["_id"]},
        {"$set": {"ingredient_vector": vector}}
    )
    updated_count += 1
    
    if updated_count % 100 == 0:
        print(f"Processed {updated_count} / {len(recipes)}...")

end_time = time.time()
print(f"✅ Migration complete! Updated {updated_count} recipes in {round(end_time - start_time, 2)} seconds.")