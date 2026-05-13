const axios = require('axios');
const Pantry = require('../models/Pantry');
const User = require('../models/User'); // We need to import the User model now!

exports.getRecommendations = async (req, res) => {
    try {
        const userId = req.user.userId;

        // 1. Fetch both the Pantry AND the User Profile
        const userPantry = await Pantry.findOne({ userId });
        const user = await User.findById(userId);
        
        if (!userPantry || userPantry.ingredients.length === 0) {
            return res.status(400).json({ message: "Your pantry is empty! Add some ingredients first." });
        }

        const userAllergies = user.profile.allergies || [];
        const userDiets = user.profile.diet || []; // Grab the diet array from the user profile

        // 2. Send BOTH ingredients and allergies to the Python AI
        const pythonResponse = await axios.post('http://localhost:8000/recommend', {
            user_id: userId,
            ingredients: userPantry.ingredients,
            allergies: userAllergies, // Added the safety payload!
            diets: userDiets,
            medical_conditions: user.profile.medicalConditions || [],
            dislikes: user.profile.dislikes || [],
            disliked_cuisines: user.profile.dislikedCuisines || []
        });

        res.status(200).json(pythonResponse.data);

    } catch (error) {
        console.error("Error getting recommendations:", error.message);
        res.status(500).json({ error: "Failed to get recommendations from AI service." });
    }
};