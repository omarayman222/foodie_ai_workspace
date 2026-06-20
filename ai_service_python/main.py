from fastapi import FastAPI
from models import PantryRequest
from engine import get_smart_recommendations

app = FastAPI(title="FoodieAI Recommendation Service")

@app.get("/")
def read_root():
    return {"message": "Hello from the Python AI Service! 🧠"}

@app.post("/recommend")
def get_recommendations(request: PantryRequest):
    # Call the logic from engine.py
    top_recipes = get_smart_recommendations(request.ingredients, request.allergies, request.diets, request.medical_conditions, request.dislikes, request.disliked_cuisines, request.top_n)
    
    return {
        "message": "Smart AI Recommendations generated successfully!",
        "your_pantry": request.ingredients,
        "your_allergies": request.allergies,
        "your_diets": request.diets,
        "top_recipes": top_recipes
    }