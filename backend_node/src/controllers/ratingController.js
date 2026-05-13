const Groq = require('groq-sdk');
const User = require('../models/User'); 
const Recipe = require('../models/Recipe'); // Assuming you have a Recipe model

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

const FEEDBACK_PROMPT = `
You are Foodie AI's culinary preference analyzer. 
A user just cooked a recipe and left a star rating and a feedback comment. 

Your job is to read their feedback and extract any NEW dietary preferences, likes, or dislikes to update their profile.

You MUST respond ONLY with a valid JSON object in this exact format:
{
  "profile_updates": {
    "added_dislikes": [],
    "added_likes": [],
    "added_allergies": []
  }
}
If there is no written feedback, or no clear preferences mentioned, return empty arrays.
`;

exports.rateRecipe = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { recipeId, rating, feedbackText } = req.body;

        if (!recipeId || !rating) {
            return res.status(400).json({ error: "Recipe ID and rating (1-5) are required." });
        }

        // 1. Fetch the User and the Recipe (to know what cuisine they just ate)
        const user = await User.findById(userId);
        const recipe = await Recipe.findById(recipeId);

        if (!user || !recipe) {
            return res.status(404).json({ error: "User or Recipe not found." });
        }

        // 2. Basic Adaptive Logic based purely on the Star Rating
        let databaseUpdated = false;
        
        // If they rated it a 1 or 2, assume they dislike this cuisine type (safeguard)
        if (rating <= 2 && recipe.ai_tags?.cuisine_type?.length > 0) {
            const badCuisine = recipe.ai_tags.cuisine_type[0];
            if (!user.profile.dislikedCuisines?.includes(badCuisine)) {
                user.profile.dislikedCuisines.push(badCuisine);
                databaseUpdated = true;
            }
        }

        // 3. Advanced AI Extraction (If they left a text comment)
        let extractedPreferences = {};
        if (feedbackText && feedbackText.trim() !== "") {
            const userPrompt = `Recipe: ${recipe.recipe_name}\nRating: ${rating}/5\nFeedback: "${feedbackText}"`;
            
            const chatCompletion = await groq.chat.completions.create({
                messages: [
                    { role: "system", content: FEEDBACK_PROMPT },
                    { role: "user", content: userPrompt }
                ],
                model: "llama-3.1-8b-instant",
                temperature: 0.1, // Low temp for strict data extraction
                response_format: { type: "json_object" }
            });

            const aiResponse = JSON.parse(chatCompletion.choices[0].message.content);
            extractedPreferences = aiResponse.profile_updates || {};

            // Apply AI extractions to the user profile
            if (extractedPreferences.added_dislikes?.length > 0) {
                user.profile.dislikes.push(...extractedPreferences.added_dislikes);
                databaseUpdated = true;
            }
            if (extractedPreferences.added_allergies?.length > 0) {
                user.profile.allergies.push(...extractedPreferences.added_allergies);
                databaseUpdated = true;
            }
            // (Assuming you add a "likes" array to your User schema later!)
        }

        // 4. Save the user's updated brain to the database
        if (databaseUpdated) {
            await user.save();
        }

        // Optional: Save the actual rating history to the User document so we know what they've cooked
        // user.cookedHistory.push({ recipeId, rating, feedbackText, date: new Date() });
        // await user.save();

        res.status(200).json({
            message: "Rating saved and profile adapted!",
            rating_applied: rating,
            ai_extractions: extractedPreferences
        });

    } catch (error) {
        console.error("Rating System Error:", error);
        res.status(500).json({ error: "Failed to process rating." });
    }
};