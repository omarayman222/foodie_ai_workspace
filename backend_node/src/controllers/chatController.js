const Groq = require('groq-sdk');
const axios = require('axios');
const User = require('../models/User');
// Assuming you have a Recipe model for the database
// const Recipe = require('../models/Recipe'); 

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

exports.processChat = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { message, currentRecipeId } = req.body; 
        // 'currentRecipeId' lets us know if they are currently looking at a recipe

        if (!message) {
            return res.status(400).json({ error: "Message is required." });
        }

        const user = await User.findById(userId);
        if (!user) return res.status(404).json({ error: "User not found." });

        console.log(`🤖 Received Message: "${message}"`);

        // ==========================================
        // STEP 1: INTENT CLASSIFICATION
        // ==========================================
        const classifierPrompt = `
            Analyze the user's message: "${message}".
            Classify their intent into exactly ONE of these three categories. Output ONLY the category name in all caps:
            1. SEARCH (They want to find, discover, or look up new recipes/meals)
            2. COOKING (They need help cooking, substituting ingredients, or asking about a specific recipe)
            3. GENERAL (They are asking about calories, nutrition, diets, or general food facts)
        `;

        const intentResponse = await groq.chat.completions.create({
            messages: [{ role: "system", content: classifierPrompt }],
            model: "llama3-8b-8192", 
            temperature: 0.1, // Strict, no creativity needed here
        });

        const intent = intentResponse.choices[0].message.content.trim().toUpperCase();
        console.log(`🚦 Traffic Cop routed to: ${intent}`);

        // ==========================================
        // STEP 2: THE SWITCHBOARD
        // ==========================================
        
        let finalReply = "";
        let finalRecipes = []; // Only populated if it's a SEARCH

        if (intent.includes("SEARCH")) {
            // --- ROUTE A: SEARCH & DISCOVERY ---
            
            // 1. Extract what they want and don't want
            const extractPrompt = `
                Extract data from: "${message}". 
                Respond ONLY with valid JSON: {"wanted": ["item1"], "unwanted": ["item1"]}
            `;
            const extractRes = await groq.chat.completions.create({
                messages: [{ role: "system", content: extractPrompt }],
                model: "llama3-8b-8192", temperature: 0.1
            });
            const searchData = JSON.parse(extractRes.choices[0].message.content);

            // 2. Merge with permanent profile
            const pythonPayload = {
                user_id: userId.toString(),
                ingredients: searchData.wanted || [], 
                allergies: user.profile.allergies || [],
                diets: user.profile.diet || [],
                medical_conditions: user.profile.medicalConditions || [],
                dislikes: [...(user.profile.dislikes || []), ...(searchData.unwanted || [])],
                disliked_cuisines: user.profile.dislikedCuisines || []
            };

            // 3. Call the Python Engine
            const pythonResponse = await axios.post('http://127.0.0.1:8000/recommend', pythonPayload);
            finalRecipes = pythonResponse.data.top_recipes || pythonResponse.data;

            // 4. Have Groq format a friendly response
            finalReply = `I found some great options for you! I've filtered out your allergies and made sure they match what you're craving. Check out the recipe cards below.`;

        } 
        
        else if (intent.includes("COOKING")) {
            // --- ROUTE B: THE SOUS-CHEF ---
            
            if (!currentRecipeId) {
                finalReply = "I'd love to help you cook! Please select a recipe from your dashboard first so I know what we're making.";
            } else {
                // In a real scenario, you'd fetch the recipe details from MongoDB here
                // const recipe = await Recipe.findById(currentRecipeId);
                
                const cookingPrompt = `
                    You are Foodie AI, an expert Sous-Chef. 
                    The user is currently cooking. Answer their question concisely and practically.
                    User: ${message}
                `;
                
                const aiResponse = await groq.chat.completions.create({
                    messages: [{ role: "system", content: cookingPrompt }],
                    model: "llama3-70b-8192", // Use the smarter model for cooking advice
                    temperature: 0.7,
                });
                
                finalReply = aiResponse.choices[0].message.content;
            }
        } 
        
        else {
            // --- ROUTE C: GENERAL NUTRITION & FACTS ---
            
            const generalPrompt = `
                You are Foodie AI, a certified nutritionist and culinary expert.
                The user has the following medical profile: Allergies: ${user.profile.allergies.join(', ')}, Diets: ${user.profile.diet.join(', ')}.
                Answer their question accurately and safely, keeping their profile in mind.
                User: ${message}
            `;
            
            const aiResponse = await groq.chat.completions.create({
                messages: [{ role: "system", content: generalPrompt }],
                model: "llama3-70b-8192",
                temperature: 0.5,
            });
            
            finalReply = aiResponse.choices[0].message.content;
        }

        // ==========================================
        // STEP 3: SEND UNIFIED RESPONSE TO FLUTTER
        // ==========================================
        res.status(200).json({
            type: intent, // Tells Flutter what kind of UI to draw
            reply: finalReply,
            recipes: finalRecipes // Will be empty unless intent was SEARCH
        });

    } catch (error) {
        console.error("Chat Controller Error:", error);
        res.status(500).json({ error: "Foodie AI is currently offline." });
    }
};