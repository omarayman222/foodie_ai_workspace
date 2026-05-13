const Groq = require('groq-sdk');
const User = require('../models/User');
const Recipe = require('../models/Recipe');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

const SUBSTITUTION_PROMPT = `
You are an expert culinary food scientist. A user needs an ingredient substitution for a specific recipe.

CRITICAL SAFETY RULES:
1. I will provide the user's allergies, diets, and medical conditions.
2. You MUST NOT suggest any substitute that violates these health profiles. 
3. The substitution must make culinary sense for the specific recipe provided.

You MUST respond ONLY with a valid JSON object in this exact format:
{
  "substitutions": [
    {
      "name": "Exact Name of Substitute Ingredient",
      "ratio": "E.g., Use 1 cup of X for every 1 cup of original",
      "preparation_instructions": "Any special prep needed",
      "culinary_impact": "How will this change the flavor or texture of the final dish?"
    }
  ]
}
Provide up to 3 of the best, safest options.
`;

exports.getSubstitution = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { recipeId, ingredientToReplace } = req.body;

        if (!recipeId || !ingredientToReplace) {
            return res.status(400).json({ error: "Please provide a recipeId and the ingredientToReplace." });
        }

        // 1. Fetch User (for safety constraints) and Recipe (for culinary context)
        const user = await User.findById(userId);
        const recipe = await Recipe.findById(recipeId);

        if (!user || !recipe) {
            return res.status(404).json({ error: "User or Recipe not found." });
        }

        // 2. Build the context-aware prompt
        const userPrompt = `
        Recipe Name: ${recipe.recipe_name}
        Original Ingredients: ${recipe.ingredients.join(', ')}
        
        Ingredient to Replace: "${ingredientToReplace}"
        
        USER HEALTH CONSTRAINTS (DO NOT VIOLATE):
        Allergies: ${user.profile.allergies.join(', ') || 'None'}
        Diet: ${user.profile.diet.join(', ') || 'None'}
        Medical: ${user.profile.medicalConditions.join(', ') || 'None'}
        `;

        // 3. Ask Groq for safe substitutions
        const chatCompletion = await groq.chat.completions.create({
            messages: [
                { role: "system", content: SUBSTITUTION_PROMPT },
                { role: "user", content: userPrompt }
            ],
            model: "llama-3.1-8b-instant",
            temperature: 0.2, // Low temperature for high accuracy/safety
            response_format: { type: "json_object" }
        });

        // 4. Return the structured data to the Flutter frontend
        const aiResponse = JSON.parse(chatCompletion.choices[0].message.content);
        
        res.status(200).json({
            original_ingredient: ingredientToReplace,
            recipe_context: recipe.recipe_name,
            safety_applied: {
                allergies_avoided: user.profile.allergies,
                diets_respected: user.profile.diet
            },
            suggestions: aiResponse.substitutions
        });

    } catch (error) {
        console.error("Substitution Error:", error);
        res.status(500).json({ error: "Failed to generate substitutions." });
    }
};