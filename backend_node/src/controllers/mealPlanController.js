const axios = require('axios');
const Pantry = require('../models/Pantry');
const User = require('../models/User');
const Recipe = require('../models/Recipe');

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

exports.getMealPlan = async (req, res) => {
    try {
        const userId = req.user.userId;

        const [user, pantry] = await Promise.all([
            User.findById(userId),
            Pantry.findOne({ userId }),
        ]);

        if (!user) return res.status(404).json({ error: 'User not found' });

        // Resolve pantry ingredients (prefer rich items, fall back to legacy strings)
        const now = new Date();
        const pantryItems = pantry?.items?.length
            ? pantry.items.filter(i => !i.expiryDate || new Date(i.expiryDate) >= now)
            : [];
        const ingredients = pantryItems.length
            ? pantryItems.map(i => i.name)
            : (pantry?.ingredients || []);

        const pythonPayload = {
            user_id: userId.toString(),
            ingredients,
            allergies: user.profile.allergies || [],
            diets: user.profile.diet || [],
            medical_conditions: user.profile.medicalConditions || [],
            dislikes: user.profile.dislikes || [],
            disliked_cuisines: user.profile.dislikedCuisines || [],
            top_n: 14,
        };

        let recipes = [];
        try {
            const pythonResponse = await axios.post('http://127.0.0.1:8000/recommend', pythonPayload, { timeout: 10000 });
            recipes = pythonResponse.data.top_recipes || [];
        } catch (e) {
            console.warn('Python service unavailable, using MongoDB fallback for meal plan.');
        }

        // MongoDB fallback: fetch 14 recipes when Python is offline
        if (recipes.length === 0) {
            const filter = {};
            if (ingredients.length > 0) {
                filter.$or = [
                    { recipe_name: { $regex: ingredients[0], $options: 'i' } },
                    { ingredients: { $regex: ingredients[0], $options: 'i' } },
                ];
            }
            const dislikedCuisines = user.profile.dislikedCuisines || [];
            if (dislikedCuisines.length > 0) {
                filter.cuisine_path = { $not: new RegExp(dislikedCuisines.join('|'), 'i') };
            }

            let mongoRecipes = await Recipe.find(filter)
                .limit(14)
                .select('recipe_name prep_time cook_time total_time servings ingredients cuisine_path img_src rating nutrition directions');

            // Not enough from pantry search — pad with popular recipes
            if (mongoRecipes.length < 14) {
                const existingIds = mongoRecipes.map(r => r._id);
                const extra = await Recipe.find({ _id: { $nin: existingIds } })
                    .limit(14 - mongoRecipes.length)
                    .select('recipe_name prep_time cook_time total_time servings ingredients cuisine_path img_src rating nutrition directions');
                mongoRecipes = [...mongoRecipes, ...extra];
            }

            recipes = mongoRecipes.map(r => { const obj = r.toObject(); return { ...obj, _id: obj._id.toString() }; });
        }

        // Build a 7-day plan: assign lunch + dinner without repeating the same recipe
        // on the same day; if we run out, cycle through from the start
        const plan = DAYS.map((day, i) => {
            const lunchIdx  = (i * 2)     % Math.max(recipes.length, 1);
            const dinnerIdx = (i * 2 + 1) % Math.max(recipes.length, 1);

            const lunch  = recipes.length > 0 ? recipes[lunchIdx]  : null;
            // Only use dinnerIdx if it's different from lunch (avoid same-meal same-day)
            const dinner = recipes.length > 1 ? recipes[dinnerIdx] : null;

            return { day, lunch, dinner };
        });

        res.json({ plan, totalRecipes: recipes.length });
    } catch (e) {
        console.error('Meal plan error:', e.message);
        res.status(500).json({ error: 'Failed to generate meal plan' });
    }
};
