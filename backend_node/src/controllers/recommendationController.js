const axios = require('axios');
const User = require('../models/User');
const Pantry = require('../models/Pantry');

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

        console.log("PAYLOAD LEAVING NODE:", JSON.stringify(pythonPayload, null, 2));

        const pythonResponse = await axios.post('http://127.0.0.1:8000/recommend', pythonPayload, { timeout: 10000 });

        res.status(200).json({
            message: "Recommendations successfully generated!",
            recipes: pythonResponse.data.top_recipes || pythonResponse.data
        });

    } catch (error) {
        if (error.response) {
            console.error("FastAPI Rejected the Payload. Reason:", JSON.stringify(error.response.data, null, 2));
            return res.status(422).json({
                error: "Python rejected the data shape.",
                details: error.response.data
            });
        }

        console.error("Bridge Error:", error.message);
        res.status(503).json({ error: "Recommendation Engine is offline." });
    }
};
