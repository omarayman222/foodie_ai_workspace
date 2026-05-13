const axios = require('axios');
const User = require('../models/User');

exports.getRecommendations = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId);

        if (!user) {
            return res.status(404).json({ error: "User not found." });
        }

        // 1. Package the user's brain into a payload for Python
        // Using the exact keys Python expects in models.py
        const pythonPayload = {
            user_id: userId.toString(),
            ingredients: user.pantry || [], 
            allergies: user.profile.allergies || [],
            diets: user.profile.diet || [],
            medical_conditions: user.profile.medicalConditions || [], 
            dislikes: user.profile.dislikes || [],
            disliked_cuisines: user.profile.dislikedCuisines || []
        };

        console.log("PAYLOAD LEAVING NODE:", JSON.stringify(pythonPayload, null, 2));

        // 2. Call your Python Microservice! 
        const pythonResponse = await axios.post('http://127.0.0.1:8000/recommend', pythonPayload);

        // 3. Return the brilliant math results back to the Flutter app
        res.status(200).json({
            message: "Recommendations successfully generated!",
            recipes: pythonResponse.data.top_recipes || pythonResponse.data 
        });

    } catch (error) {
        if (error.response) {
            // This captures the EXACT reason FastAPI rejected the payload
            console.error("🛑 FastAPI Rejected the Payload. Reason:", JSON.stringify(error.response.data, null, 2));
            return res.status(422).json({ 
                error: "Python rejected the data shape.", 
                details: error.response.data 
            });
        }
        
        console.error("Bridge Error:", error.message);
        res.status(503).json({ error: "Recommendation Engine is offline." });
    }
};