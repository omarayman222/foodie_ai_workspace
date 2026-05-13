const Groq = require('groq-sdk');
const User = require('../models/User');
const Recipe = require('../models/Recipe');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

exports.sousChefChat = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { recipeId, currentStepIndex, userMessage, chatHistory } = req.body;

        if (!recipeId || !userMessage) {
            return res.status(400).json({ error: "Recipe ID and user message are required." });
        }

        const user = await User.findById(userId);
        const recipe = await Recipe.findById(recipeId);

        if (!user || !recipe) {
            return res.status(404).json({ error: "User or Recipe not found." });
        }

        // Split directions into an array if they are a single string
        const steps = typeof recipe.directions === 'string' 
            ? recipe.directions.split('\n').filter(s => s.trim() !== '') 
            : recipe.directions;
            
        const currentStep = steps[currentStepIndex] || "Recipe complete.";

        // THE INTEGRATION PROMPT: This brings all your features together
        const SOUS_CHEF_PROMPT = `
        You are Foodie AI, an interactive Sous-Chef guiding the user through cooking: ${recipe.recipe_name}.
        
        CONTEXT:
        - The user is currently on Step ${currentStepIndex + 1}: "${currentStep}"
        - Full Ingredients: ${recipe.ingredients.join(', ')}
        - User's Health Constraints: Allergies (${user.profile.allergies.join(', ') || 'None'}), Diets (${user.profile.diet.join(', ') || 'None'})

        RULES:
        1. Answer the user's specific question about the current step.
        2. If they ask for an ingredient substitution (Feature 6.3), provide one that strictly obeys their health constraints.
        3. Keep your answers short, encouraging, and easy to read while cooking. Do not overwhelm them with text.
        4. If they say "next" or "done", tell them what the next step is.
        `;

        // Format the previous chat history for Groq
        const messages = [
            { role: "system", content: SOUS_CHEF_PROMPT },
            ...(chatHistory || []), // Pass previous messages so it remembers the conversation
            { role: "user", content: userMessage }
        ];

        const chatCompletion = await groq.chat.completions.create({
            messages: messages,
            model: "llama-3.1-8b-instant",
            temperature: 0.4, 
        });

        res.status(200).json({
            reply: chatCompletion.choices[0].message.content,
            current_step: currentStepIndex // The frontend can update this if the AI detects they moved on
        });

    } catch (error) {
        console.error("Sous-Chef Error:", error);
        res.status(500).json({ error: "Failed to communicate with Sous-Chef." });
    }
};