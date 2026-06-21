const axios = require('axios');
const User = require('../models/User');
const Pantry = require('../models/Pantry');
const Recipe = require('../models/Recipe');

exports.getRecommendations = async (req, res) => {
    try {
        const userId = req.user.userId;
        const [user, pantryDoc] = await Promise.all([
            User.findById(userId),
            Pantry.findOne({ userId }),
        ]);

        if (!user) {
            return res.status(404).json({ error: "User not found." });
        }

        // Filter expired pantry items and collect ingredient names
        const now = new Date();
        const pantryItems = (pantryDoc?.items || [])
            .filter(i => !i.expiryDate || new Date(i.expiryDate) >= now)
            .map(i => i.name);

        const pythonPayload = {
            user_id: userId.toString(),
            ingredients: pantryItems,
            allergies: user.profile.allergies || [],
            diets: user.profile.diet || [],
            medical_conditions: user.profile.medicalConditions || [],
            dislikes: user.profile.dislikes || [],
            disliked_cuisines: user.profile.dislikedCuisines || []
        };

        // Try Python AI service first
        try {
            const pythonResponse = await axios.post('http://127.0.0.1:8000/recommend', pythonPayload, { timeout: 10000 });
            return res.status(200).json({
                message: "Recommendations successfully generated!",
                recipes: pythonResponse.data.top_recipes || pythonResponse.data
            });
        } catch (pythonError) {
            const isOffline = pythonError.code === 'ECONNREFUSED' || pythonError.code === 'ETIMEDOUT' || pythonError.code === 'ECONNABORTED';
            if (!isOffline) {
                console.error("FastAPI Rejected the Payload:", pythonError.response?.data);
            }
            console.warn("Python service unavailable, falling back to MongoDB recommendations.");
        }

        // MongoDB fallback: search by pantry items or return popular recipes
        const filter = {};
        if (pantryItems.length > 0) {
            const keyword = pantryItems[0];
            filter.$or = [
                { recipe_name:  { $regex: keyword, $options: 'i' } },
                { ingredients:  { $regex: keyword, $options: 'i' } },
            ];
        }

        // Exclude disliked cuisines
        const dislikedCuisines = user.profile.dislikedCuisines || [];
        if (dislikedCuisines.length > 0) {
            filter.cuisine_path = { $not: new RegExp(dislikedCuisines.join('|'), 'i') };
        }

        const mongoRecipes = await Recipe.find(filter)
            .limit(10)
            .select('recipe_name prep_time cook_time total_time servings ingredients cuisine_path img_src rating nutrition directions');

        // If pantry search returned nothing, fetch a general popular set
        let recipes = mongoRecipes.length > 0
            ? mongoRecipes
            : await Recipe.find(dislikedCuisines.length > 0 ? filter : {})
                .limit(10)
                .select('recipe_name prep_time cook_time total_time servings ingredients cuisine_path img_src rating nutrition directions');

        const formatted = recipes.map(r => { const obj = r.toObject(); return { ...obj, _id: obj._id.toString() }; });

        return res.status(200).json({
            message: pantryItems.length > 0
                ? `Found ${formatted.length} recipes matching your pantry!`
                : `Here are some popular recipes for you!`,
            recipes: formatted
        });

    } catch (error) {
        console.error("Recommendation Controller Error:", error.message);
        res.status(500).json({ error: "Failed to fetch recommendations." });
    }
};
