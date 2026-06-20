const axios = require('axios');
const Pantry = require('../models/Pantry');
const Recipe = require('../models/Recipe');
const User = require('../models/User');

exports.getRecommendations = async (req, res) => {
    try {
        const userId = req.user.userId;
        const userPantry = await Pantry.findOne({ userId });
        const user = await User.findById(userId);

        const ingredients = userPantry
            ? userPantry.items && userPantry.items.length > 0
                ? userPantry.items.map(i => i.name)
                : (userPantry.ingredients || [])
            : [];

        if (ingredients.length === 0) {
            return res.status(400).json({ message: 'Your pantry is empty! Add some ingredients first.' });
        }

        const pythonResponse = await axios.post('http://localhost:8000/recommend', {
            user_id: userId,
            ingredients,
            allergies: user.profile.allergies || [],
            diets: user.profile.diet || [],
            medical_conditions: user.profile.medicalConditions || [],
            dislikes: user.profile.dislikes || [],
            disliked_cuisines: user.profile.dislikedCuisines || [],
        }, { timeout: 10000 });

        res.status(200).json(pythonResponse.data);
    } catch (error) {
        console.error('Error getting recommendations:', error.message);
        const isOffline = error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT' || error.code === 'ECONNABORTED';
        res.status(isOffline ? 503 : 500).json({ error: 'Recommendation service is currently offline.' });
    }
};

// GET /api/recipes/search?q=pasta&cuisine=italian&maxTime=30&page=1
exports.searchRecipes = async (req, res) => {
    try {
        const { q = '', cuisine = '', maxTime = '', page = 1 } = req.query;
        const limit = 20;
        const skip  = (parseInt(page) - 1) * limit;

        const filter = {};
        if (q) {
            filter.$or = [
                { recipe_name:  { $regex: q, $options: 'i' } },
                { ingredients:  { $regex: q, $options: 'i' } },
            ];
        }
        if (cuisine) {
            filter.cuisine_path = { $regex: cuisine, $options: 'i' };
        }
        // maxTime filter: parse minutes from total_time string
        // We store it as string like "30 mins" — skip server-side if complex
        // and let the client filter for simplicity

        const [recipes, total] = await Promise.all([
            Recipe.find(filter).skip(skip).limit(limit).select(
                'recipe_name prep_time cook_time total_time servings ingredients cuisine_path img_src rating nutrition'
            ),
            Recipe.countDocuments(filter),
        ]);

        res.json({ recipes, total, page: parseInt(page), limit });
    } catch (e) {
        console.error('Search error:', e.message);
        res.status(500).json({ error: 'Search failed' });
    }
};
