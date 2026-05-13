const Groq = require('groq-sdk');
const User = require('../models/User'); // Ensure this points to your User model

// Initialize Groq with the key from your .env file
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// THE UPGRADE: We added cuisine_dislikes and pantry_updates to the strict JSON format.
const SYSTEM_PROMPT = `
You are Foodie AI, a friendly, professional culinary assistant. 
You are chatting with a user about food, recipes, their dietary preferences, and what ingredients they have at home.

Your goal is TWO-FOLD:
1. Write a friendly, helpful reply to the user.
2. Extract any profile updates (allergies, diets, medical, disliked ingredients, disliked cuisines).
3. Extract any pantry updates (ingredients they just bought/added, or ingredients they ran out of/removed).

You MUST respond ONLY with a valid JSON object in this exact format. Do not add markdown or extra text. Use empty arrays if nothing applies.
{
  "reply_to_user": "Your friendly conversational response here.",
  "profile_updates": {
    "added_allergies": [],
    "added_diets": [],
    "added_medical": [],
    "added_dislikes": [],
    "disliked_cuisines": []
  },
  "pantry_updates": {
    "add_items": [],
    "remove_items": []
  }
}
`;

exports.handleChat = async (req, res) => {
    try {
        const userId = req.user.userId; // Assuming you have auth middleware
        const { message } = req.body;

        if (!message) {
            return res.status(400).json({ error: "Please provide a message." });
        }

        // 1. Call the Groq API
        const chatCompletion = await groq.chat.completions.create({
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                { role: "user", content: message }
            ],
            model: "llama-3.1-8b-instant",
            temperature: 0.5,
            response_format: { type: "json_object" } // Forces perfect JSON!
        });

        // 2. Parse the AI's JSON response
        const aiResponse = JSON.parse(chatCompletion.choices[0].message.content);
        const profileUpdates = aiResponse.profile_updates || {};
        const pantryUpdates = aiResponse.pantry_updates || {};

        // 3. Update the User's Database Profile
        let databaseUpdated = false;
        const user = await User.findById(userId);

        if (user) {
            // --- HANDLE PROFILE PREFERENCES ---
            if (profileUpdates.added_allergies?.length > 0) {
                user.profile.allergies.push(...profileUpdates.added_allergies);
                databaseUpdated = true;
            }
            if (profileUpdates.added_diets?.length > 0) {
                user.profile.diet.push(...profileUpdates.added_diets);
                databaseUpdated = true;
            }
            if (profileUpdates.added_dislikes?.length > 0) {
                user.profile.dislikes.push(...profileUpdates.added_dislikes);
                databaseUpdated = true;
            }
            if (profileUpdates.added_medical?.length > 0) {
                user.profile.medicalConditions.push(...profileUpdates.added_medical);
                databaseUpdated = true;
            }
            if (profileUpdates.disliked_cuisines?.length > 0) {
                // Assuming your User model has a dislikedCuisines array
                user.profile.dislikedCuisines.push(...profileUpdates.disliked_cuisines);
                databaseUpdated = true;
            }

            // --- HANDLE PANTRY INVENTORY ---
            if (pantryUpdates.add_items?.length > 0) {
                // Ensure all items are lowercase for consistent searching later
                const newItems = pantryUpdates.add_items.map(item => item.toLowerCase());
                user.pantry.push(...newItems);
                databaseUpdated = true;
            }
            if (pantryUpdates.remove_items?.length > 0) {
                const itemsToRemove = pantryUpdates.remove_items.map(item => item.toLowerCase());
                // Filter out the items the user told the AI they ran out of
                user.pantry = user.pantry.filter(item => !itemsToRemove.includes(item));
                databaseUpdated = true;
            }

            // Save all changes in one single database call
            if (databaseUpdated) {
                await user.save();
            }
        }

        // 4. Send the friendly reply back to the Flutter app!
        res.status(200).json({
            reply: aiResponse.reply_to_user,
            database_was_updated: databaseUpdated,
            extracted_data: {
                profile: profileUpdates,
                pantry: pantryUpdates
            }
        });

    } catch (error) {
        console.error("Chatbot Error:", error);
        res.status(500).json({ error: "Failed to communicate with Foodie AI." });
    }
};