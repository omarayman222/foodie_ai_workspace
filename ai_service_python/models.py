from pydantic import BaseModel

class PantryRequest(BaseModel):
    user_id: str
    ingredients: list[str]
    allergies: list[str] = []
    diets: list[str] = []
    medical_conditions: list[str] = [] # NEW
    dislikes: list[str] = []           # NEW
    disliked_cuisines: list[str] = []  # NEW
    top_n: int = 14