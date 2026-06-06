const axios = require('axios');
const Pantry = require('../models/Pantry');
const User = require('../models/User');

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

exports.getMealPlan = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId);
        if (!user) return res.status(404).json({ error: 'User not found' });

        const pantry = await Pantry.findOne({ userId });
        const ingredients = pantry
            ? pantry.items && pantry.items.length > 0
                ? pantry.items.map(i => i.name)
                : (pantry.ingredients || [])
            : [];

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
            const pythonResponse = await axios.post('http://127.0.0.1:8000/recommend', pythonPayload);
            recipes = pythonResponse.data.top_recipes || [];
        } catch (e) {
            // AI service offline — still return empty plan gracefully
            console.error('Python service error:', e.message);
        }

        // Build a 7-day plan: lunch + dinner per day
        const plan = DAYS.map((day, i) => ({
            day,
            lunch:  recipes[i * 2]     || null,
            dinner: recipes[i * 2 + 1] || recipes[i % recipes.length] || null,
        }));

        res.json({ plan, totalRecipes: recipes.length });
    } catch (e) {
        console.error('Meal plan error:', e.message);
        res.status(500).json({ error: 'Failed to generate meal plan' });
    }
};
