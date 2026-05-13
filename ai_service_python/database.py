from pymongo import MongoClient

# Connect to MongoDB
client = MongoClient("mongodb://localhost:27017/")
db = client["foodieai_db"] 
recipes_collection = db["recipes"]