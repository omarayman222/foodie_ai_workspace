const Groq = require('groq-sdk');
const axios = require('axios');
const User = require('../models/User');
const Pantry = require('../models/Pantry');
const Recipe = require('../models/Recipe');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ── Simple TTL in-memory cache ─────────────────────────────────────────────
// Stores: key → { reply, type, recipes, expiresAt }
// Key is built from (userId + normalised message) so it's per-user.
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const _cache = new Map();

function cacheGet(key) {
    const entry = _cache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) { _cache.delete(key); return null; }
    return entry.value;
}

function cacheSet(key, value) {
    if (_cache.size > 500) {
        // Evict oldest entry to prevent unbounded growth
        _cache.delete(_cache.keys().next().value);
    }
    _cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
}

// ── Helper: safe Groq call with timeout ───────────────────────────────────
async function groqChat(messages, { model, temperature = 0.5, max_tokens = 512, json = false } = {}) {
    const opts = {
        messages,
        model,
        temperature,
        max_tokens,
    };
    if (json) opts.response_format = { type: 'json_object' };
    return groq.chat.completions.create(opts, { timeout: 15_000 });
}

exports.processChat = async (req, res) => {
    const t0 = Date.now();
    try {
        const userId = req.user.userId;
        const { message, currentRecipeId } = req.body;

        if (!message) {
            return res.status(400).json({ error: 'Message is required.' });
        }

        // ── Cache lookup (skip for searches with recipe context) ──────────
        const cacheKey = `${userId}:${message.toLowerCase().trim()}`;
        if (!currentRecipeId) {
            const cached = cacheGet(cacheKey);
            if (cached) {
                console.log(`[chat] cache HIT  (${Date.now() - t0}ms)`);
                return res.status(200).json(cached);
            }
        }

        // ── STEP 1: DB load + intent classification IN PARALLEL ───────────
        const classifierPrompt = `Classify the user message into exactly ONE of these categories.
Output ONLY the category name in ALL CAPS, nothing else.

SEARCH   – user wants to find or discover recipes/meals
COOKING  – user needs cooking help, technique advice, substitutions, or step-by-step guidance
GENERAL  – user asks about nutrition, calories, diets, food facts, or health

Message: "${message}"`;

        const [dbResults, intentResponse] = await Promise.all([
            Promise.all([
                User.findById(userId),
                Pantry.findOne({ userId }),
                currentRecipeId ? Recipe.findById(currentRecipeId).catch(() => null) : Promise.resolve(null),
            ]),
            groqChat(
                [{ role: 'system', content: classifierPrompt }],
                { model: 'llama-3.1-8b-instant', temperature: 0.0, max_tokens: 10 }
            ),
        ]);

        const [user, pantry, currentRecipe] = dbResults;

        if (!user) return res.status(404).json({ error: 'User not found.' });

        const intent = intentResponse.choices[0].message.content.trim().toUpperCase();
        console.log(`[chat] intent:${intent}  classify:${Date.now() - t0}ms`);

        // ── Build context strings ─────────────────────────────────────────
        const now = new Date();
        const pantryNames = (pantry?.items || [])
            .filter(i => !i.expiryDate || new Date(i.expiryDate) >= now)
            .map(i => i.name);

        const pantryContext = pantryNames.length > 0
            ? `The user has these ingredients in their pantry: ${pantryNames.join(', ')}.`
            : 'The user has no pantry items saved.';

        const profileContext = `- Allergies: ${(user.profile.allergies || []).join(', ') || 'none'}
- Diet: ${(user.profile.diet || []).join(', ') || 'none'}
- Medical conditions: ${(user.profile.medicalConditions || []).join(', ') || 'none'}
- Dislikes: ${(user.profile.dislikes || []).join(', ') || 'none'}`;

        // ── STEP 2: ROUTE ─────────────────────────────────────────────────
        let finalReply = '';
        let finalRecipes = [];

        // ── A: SEARCH ─────────────────────────────────────────────────────
        if (intent.includes('SEARCH')) {

            const extractPrompt = `Extract from: "${message}".
Respond ONLY with valid JSON, no extra text: {"wanted": ["ingredient or dish"], "unwanted": ["item"]}`;

            // Run LLM extraction and a broad DB fallback search in parallel
            const broadKeyword = message.split(' ').find(w => w.length > 3) || '';
            const [extractRes, broadResults] = await Promise.all([
                groqChat(
                    [{ role: 'system', content: extractPrompt }],
                    { model: 'llama-3.1-8b-instant', temperature: 0.0, max_tokens: 80, json: true }
                ),
                broadKeyword
                    ? Recipe.find({
                        $or: [
                            { recipe_name:  { $regex: broadKeyword, $options: 'i' } },
                            { ingredients:  { $regex: broadKeyword, $options: 'i' } },
                        ],
                    }).limit(10).select('recipe_name prep_time cook_time total_time servings ingredients cuisine_path img_src rating nutrition directions').lean()
                    : Promise.resolve([]),
            ]);

            let searchData = { wanted: [], unwanted: [] };
            try { searchData = JSON.parse(extractRes.choices[0].message.content); } catch (_) {}

            const wantedSet = new Set([...(searchData.wanted || []), ...pantryNames]);
            const mergedWanted = [...wantedSet];

            // Try Python AI service first
            try {
                const pythonPayload = {
                    user_id: userId.toString(),
                    ingredients: mergedWanted,
                    allergies: user.profile.allergies || [],
                    diets: user.profile.diet || [],
                    medical_conditions: user.profile.medicalConditions || [],
                    dislikes: [...(user.profile.dislikes || []), ...(searchData.unwanted || [])],
                    disliked_cuisines: user.profile.dislikedCuisines || [],
                };
                const pythonResponse = await axios.post('http://127.0.0.1:8000/recommend', pythonPayload, { timeout: 8_000 });
                finalRecipes = pythonResponse.data.top_recipes || pythonResponse.data || [];
            } catch (_) {
                // Python offline — use the broad results we already fetched
            }

            // Fall back to the broad results if Python didn't respond
            if (!Array.isArray(finalRecipes) || finalRecipes.length === 0) {
                const keywords = [...(searchData.wanted || []), ...pantryNames]
                    .map(k => k.trim())
                    .filter(k => k.length > 2);

                const primaryKeyword = keywords[0] || broadKeyword;

                if (primaryKeyword && primaryKeyword !== broadKeyword) {
                    // Refine with the extracted keyword if it differs from the broad one
                    const refined = await Recipe.find({
                        $or: [
                            { recipe_name:  { $regex: primaryKeyword, $options: 'i' } },
                            { ingredients:  { $regex: primaryKeyword, $options: 'i' } },
                            { cuisine_path: { $regex: primaryKeyword, $options: 'i' } },
                        ],
                    }).limit(10).select('recipe_name prep_time cook_time total_time servings ingredients cuisine_path img_src rating nutrition directions').lean();

                    finalRecipes = refined.length > 0 ? refined : broadResults;
                } else {
                    finalRecipes = broadResults;
                }

                // Normalise _id to string
                finalRecipes = finalRecipes.map(r => ({ ...r, _id: r._id?.toString?.() ?? r._id }));
            }

            finalReply = finalRecipes.length > 0
                ? pantryNames.length > 0
                    ? `Found ${finalRecipes.length} recipe${finalRecipes.length > 1 ? 's' : ''} that work with your pantry (${pantryNames.slice(0, 3).join(', ')}${pantryNames.length > 3 ? '…' : ''}), filtered for your preferences!`
                    : `Found ${finalRecipes.length} recipe${finalRecipes.length > 1 ? 's' : ''} matching your request!`
                : "I couldn't find any matching recipes. Try a different search term, or add more ingredients to your pantry so I can suggest meals you can make!";

        // ── B: COOKING ────────────────────────────────────────────────────
        } else if (intent.includes('COOKING')) {

            let recipeContext = '';
            if (currentRecipe) {
                // Truncate directions to avoid excessive token usage
                const directions = (currentRecipe.directions || '').substring(0, 600);
                recipeContext = `\nCurrent recipe: ${currentRecipe.recipe_name}
Ingredients: ${(currentRecipe.ingredients || []).join(', ')}
Directions (summary): ${directions}${directions.length === 600 ? '…' : ''}
Cook time: ${currentRecipe.cook_time || 'Unknown'}`;
            }

            const cookingPrompt = `You are Foodie AI, an expert sous-chef and culinary guide.

User profile:
${profileContext}

${pantryContext}${recipeContext}

Answer the user's cooking question concisely and practically (3–5 sentences max).
Suggest pantry ingredients they already have when relevant.
Never suggest ingredients that conflict with their allergies or diet.

User: ${message}`;

            const aiResponse = await groqChat(
                [{ role: 'system', content: cookingPrompt }],
                { model: 'llama-3.3-70b-versatile', temperature: 0.7, max_tokens: 350 }
            );
            finalReply = aiResponse.choices[0].message.content;

        // ── C: GENERAL ────────────────────────────────────────────────────
        } else {

            const generalPrompt = `You are Foodie AI, a certified nutritionist and culinary expert.

User profile:
${profileContext}

${pantryContext}

Answer the user's question accurately, keeping their health profile in mind.
Keep responses concise and practical (3–5 sentences max).

User: ${message}`;

            const aiResponse = await groqChat(
                [{ role: 'system', content: generalPrompt }],
                { model: 'llama-3.3-70b-versatile', temperature: 0.5, max_tokens: 300 }
            );
            finalReply = aiResponse.choices[0].message.content;
        }

        // ── STEP 3: RESPOND + CACHE ───────────────────────────────────────
        const payload = { type: intent, reply: finalReply, recipes: finalRecipes };

        if (!currentRecipeId) cacheSet(cacheKey, payload);

        console.log(`[chat] done  intent:${intent}  total:${Date.now() - t0}ms`);
        res.status(200).json(payload);

    } catch (error) {
        console.error('[chat] error:', error.message || error);
        res.status(500).json({ error: 'Foodie AI is currently offline.' });
    }
};
