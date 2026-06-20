const axios = require('axios');
const Pantry = require('../models/Pantry');
const User = require('../models/User');

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
            console.error('Python service error:', e.message);
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
