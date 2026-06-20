const Groq = require('groq-sdk');
const axios = require('axios');
const User = require('../models/User');
const Pantry = require('../models/Pantry');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

exports.processChat = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { message, currentRecipeId } = req.body;

        if (!message) {
            return res.status(400).json({ error: "Message is required." });
        }

        // Load user and pantry in parallel
        const [user, pantry] = await Promise.all([
            User.findById(userId),
            Pantry.findOne({ userId }),
        ]);

        if (!user) return res.status(404).json({ error: "User not found." });

        // Build pantry context string (non-expired items only)
        const now = new Date();
        const pantryItems = (pantry?.items || []).filter(i => !i.expiryDate || new Date(i.expiryDate) >= now);
        const pantryNames = pantryItems.map(i => i.name);
        const pantryContext = pantryNames.length > 0
            ? `The user currently has these ingredients in their pantry: ${pantryNames.join(', ')}.`
            : 'The user has no pantry items saved.';

        console.log(`🤖 Received: "${message}" | Pantry: [${pantryNames.join(', ')}]`);

        // ── STEP 1: INTENT CLASSIFICATION ─────────────────────
        const classifierPrompt = `
            Analyze the user's message: "${message}".
            Classify their intent into exactly ONE category. Output ONLY the category name in all caps:
            1. SEARCH (They want to find, discover, or look up new recipes/meals)
            2. COOKING (They need help cooking, substituting ingredients, or asking about a specific recipe)
            3. GENERAL (They are asking about calories, nutrition, diets, or general food facts)
        `;

        const intentResponse = await groq.chat.completions.create({
            messages: [{ role: 'system', content: classifierPrompt }],
            model: 'llama-3.1-8b-instant',
            temperature: 0.1,
        });

        const intent = intentResponse.choices[0].message.content.trim().toUpperCase();
        console.log(`🚦 Intent: ${intent}`);

        // ── STEP 2: ROUTE ──────────────────────────────────────
        let finalReply = '';
        let finalRecipes = [];

        if (intent.includes('SEARCH')) {
            // --- ROUTE A: SEARCH & DISCOVERY ---

            // Extract explicit wants/unwants from the message
            const extractPrompt = `
                Extract data from: "${message}".
                Respond ONLY with valid JSON: {"wanted": ["item1"], "unwanted": ["item1"]}
            `;
            const extractRes = await groq.chat.completions.create({
                messages: [{ role: 'system', content: extractPrompt }],
                model: 'llama-3.1-8b-instant',
                temperature: 0.1,
            });

            let searchData = { wanted: [], unwanted: [] };
            try { searchData = JSON.parse(extractRes.choices[0].message.content); } catch (_) {}

            // Merge pantry items into the wanted ingredients list (deduped)
            const wantedSet = new Set([...(searchData.wanted || []), ...pantryNames]);
            const mergedWanted = [...wantedSet];

            const pythonPayload = {
                user_id: userId.toString(),
                ingredients: mergedWanted,
                allergies: user.profile.allergies || [],
                diets: user.profile.diet || [],
                medical_conditions: user.profile.medicalConditions || [],
                dislikes: [...(user.profile.dislikes || []), ...(searchData.unwanted || [])],
                disliked_cuisines: user.profile.dislikedCuisines || [],
            };

            try {
                const pythonResponse = await axios.post('http://127.0.0.1:8000/recommend', pythonPayload, { timeout: 10000 });
                finalRecipes = pythonResponse.data.top_recipes || pythonResponse.data;
            } catch (pyErr) {
                console.error('Python service unavailable for chat SEARCH:', pyErr.message);
                finalRecipes = [];
            }

            finalReply = pantryNames.length > 0
                ? `I found recipes that use what you already have in your pantry (${pantryNames.slice(0, 3).join(', ')}${pantryNames.length > 3 ? '…' : ''}), filtered for your profile. Check them out below!`
                : `I found some great options for you, filtered for your allergies and preferences. Check out the recipe cards below!`;

        } else if (intent.includes('COOKING')) {
            // --- ROUTE B: SOUS-CHEF ---

            if (!currentRecipeId) {
                finalReply = "I'd love to help you cook! Please open a specific recipe first so I know what we're making, or ask me about a dish by name.";
            } else {
                const cookingPrompt = `
                    You are Foodie AI, an expert Sous-Chef.
                    ${pantryContext}
                    The user is currently cooking. Answer their question concisely and practically.
                    Where relevant, suggest using pantry ingredients they already have.
                    User: ${message}
                `;

                const aiResponse = await groq.chat.completions.create({
                    messages: [{ role: 'system', content: cookingPrompt }],
                    model: 'llama-3.3-70b-versatile',
                    temperature: 0.7,
                });

                finalReply = aiResponse.choices[0].message.content;
            }

        } else {
            // --- ROUTE C: GENERAL NUTRITION & FACTS ---

            const generalPrompt = `
                You are Foodie AI, a certified nutritionist and culinary expert.
                The user has the following medical profile:
                - Allergies: ${(user.profile.allergies || []).join(', ') || 'none'}
                - Diets: ${(user.profile.diet || []).join(', ') || 'none'}
                ${pantryContext}
                Answer the user's question accurately and safely, keeping their profile in mind.
                If their pantry is relevant (e.g. they ask what to eat), suggest ideas using what they have.
                User: ${message}
            `;

            const aiResponse = await groq.chat.completions.create({
                messages: [{ role: 'system', content: generalPrompt }],
                model: 'llama-3.3-70b-versatile',
                temperature: 0.5,
            });

            finalReply = aiResponse.choices[0].message.content;
        }

        // ── STEP 3: UNIFIED RESPONSE ───────────────────────────
        res.status(200).json({
            type: intent,
            reply: finalReply,
            recipes: finalRecipes,
        });

    } catch (error) {
        console.error('Chat Controller Error:', error);
        res.status(500).json({ error: 'Foodie AI is currently offline.' });
    }
};
