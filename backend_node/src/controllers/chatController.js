const Groq = require('groq-sdk');
const axios = require('axios');
const User = require('../models/User');
const Pantry = require('../models/Pantry');
const Recipe = require('../models/Recipe');
const qualityLogger = require('../middleware/qualityLogger');

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

// ── Models ────────────────────────────────────────────────────────────────
const MODEL_FAST    = 'llama-3.1-8b-instant';   // ~200–400ms, used for simple questions
const MODEL_PRECISE = 'llama-3.3-70b-versatile'; // ~800ms–2s, used for complex questions

// Pick the right model based on message length and conversation depth.
// Short first-turn questions go to the fast model; complex or multi-turn go to precise.
function pickModel(message, historyLen) {
    if (historyLen > 0) return MODEL_PRECISE; // ongoing conversation needs full context handling
    if (message.length > 80) return MODEL_PRECISE; // long question → likely complex
    return MODEL_FAST;
}

// Scale max_tokens to message length — no point requesting 600 tokens for a 5-word question.
function pickMaxTokens(message, base) {
    if (message.length < 50)  return Math.min(base, 300);
    if (message.length < 120) return Math.min(base, 450);
    return base;
}

// ── Helper: safe Groq call with timeout ───────────────────────────────────
async function groqChat(messages, { model, temperature = 0.5, max_tokens = 512, json = false } = {}) {
    const opts = { messages, model, temperature, max_tokens };
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

        const { history = [] } = req.body; // array of {role, content} from Flutter

        // ── STEP 1: DB load + intent classification IN PARALLEL ───────────
        const classifierPrompt = `Classify the user message into exactly ONE of these categories.
Output ONLY the category name in ALL CAPS, nothing else.

SEARCH   – user wants to find or discover recipes/meals (e.g. "show me pasta", "what can I make with chicken")
COOKING  – user needs cooking help, technique advice, substitutions, or step-by-step guidance (e.g. "how do I fry", "can I substitute butter")
GENERAL  – user asks about nutrition, calories, diets, food facts, or health (e.g. "how many calories", "is keto healthy")
UNCLEAR  – message is a greeting, off-topic, or doesn't fit any category above

Rules:
- Use GENERAL (not COOKING) when the user asks about calorie counts, protein, carbs, or health effects.
- Use COOKING (not GENERAL) when the user asks "how do I make/cook/prepare" something, OR asks whether they CAN make/eat something given their restrictions.
- Use SEARCH when the user asks for recipe suggestions or meal ideas.
- Use UNCLEAR for greetings like "hi", "hello", "thanks", or unrelated questions.

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

        // ── Cache lookup (skip only when recipe context is present) ──────
        // Allow caching for history ≤ 2 turns — early turns are often generic questions.
        const profileHash = [...(user.profile.allergies || []), ...(user.profile.diet || [])]
            .sort().join(',');
        const recentHistory = (history || []).slice(-2);
        const historyHash   = recentHistory.map(h => `${h.role}:${h.content}`).join('|');
        const cacheKey = `${userId}:${message.toLowerCase().trim()}:${profileHash}:${historyHash}`;
        if (!currentRecipeId && history.length <= 2) {
            const cached = cacheGet(cacheKey);
            if (cached) {
                console.log(`[chat] cache HIT  (${Date.now() - t0}ms)`);
                return res.status(200).json(cached);
            }
        }

        // ── Build context strings (computed once, reused across intents) ──
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

        // Compute history messages once — used by both COOKING and GENERAL
        const historyMessages = (history || []).slice(-6).map(h => ({
            role: h.role,
            content: String(h.content),
        }));

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

            if (finalRecipes.length > 0) {
                const names = finalRecipes.slice(0, 3).map(r => r.recipe_name || r.title || '').filter(Boolean);
                const namePreview = names.length > 0 ? ` including ${names.join(', ')}` : '';
                finalReply = pantryNames.length > 0
                    ? `Found ${finalRecipes.length} recipe${finalRecipes.length > 1 ? 's' : ''}${namePreview} — filtered for your pantry and preferences!`
                    : `Found ${finalRecipes.length} recipe${finalRecipes.length > 1 ? 's' : ''}${namePreview} matching your request!`;
            } else {
                finalReply = "I couldn't find any matching recipes. Try a different search term, or add more ingredients to your pantry so I can suggest meals you can make!";
            }

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

Rules:
- Answer concisely and practically (3–6 sentences).
- Suggest pantry ingredients they already have when relevant.
- CRITICAL: Never suggest anything that conflicts with the user's allergies or diet listed above.
- Give exact temperatures, times, and quantities. If you are not certain of a number, say "approximately" and give a range — never invent a specific figure.
- Always reply in the same language the user wrote in.

Examples:
Q: "How do I know when my onions are properly caramelized?"
A: "Properly caramelized onions take 30–40 minutes on low heat. They should be deep golden-brown, very soft, and reduced to about ¼ of their original volume. If they look done in under 15 minutes, they're only softened — turn the heat down and keep going."

Q: "My chicken is dry, what went wrong?"
A: "Dry chicken usually means it was overcooked or cooked on too-high heat without resting. Chicken breast is done at 74°C (165°F) internally — anything higher dries it out fast. Next time, let it rest 5 minutes after cooking so the juices redistribute."`;

            const aiResponse = await groqChat(
                [
                    { role: 'system', content: cookingPrompt },
                    ...historyMessages,
                    { role: 'user', content: message },
                ],
                {
                    model:      pickModel(message, historyMessages.length),
                    temperature: 0.3,
                    max_tokens:  pickMaxTokens(message, 600),
                }
            );
            finalReply = aiResponse.choices[0].message.content;

        // ── C: GENERAL ────────────────────────────────────────────────────
        } else if (intent.includes('GENERAL')) {

            const generalPrompt = `You are Foodie AI, a certified nutritionist and culinary expert.

User profile:
${profileContext}

${pantryContext}

Rules:
- Answer accurately with facts. If you are not certain of a number, say "approximately" and give a range — never invent a specific figure.
- Keep the response concise and practical (3–6 sentences).
- CRITICAL: Always respect the user's medical conditions and dietary restrictions listed above.
- Always reply in the same language the user wrote in.

Examples:
Q: "How many calories are in a tablespoon of olive oil?"
A: "One tablespoon of olive oil contains about 120 calories and 14g of fat, mostly heart-healthy monounsaturated fats. It has no carbs or protein. It's a great cooking fat in moderation."

Q: "Is white rice bad for diabetics?"
A: "White rice has a high glycaemic index and raises blood sugar quickly, so it's worth limiting for diabetics. Brown rice, cauliflower rice, or smaller portions with protein and vegetables can help manage the blood sugar spike. Always check with your doctor for personalised advice."`;

            const aiResponse = await groqChat(
                [
                    { role: 'system', content: generalPrompt },
                    ...historyMessages,
                    { role: 'user', content: message },
                ],
                {
                    model:       pickModel(message, historyMessages.length),
                    temperature: 0.3,
                    max_tokens:  pickMaxTokens(message, 500),
                }
            );
            finalReply = aiResponse.choices[0].message.content;

        // ── D: UNCLEAR ────────────────────────────────────────────────────
        } else {
            finalReply = "I'm not sure what you're looking for — could you clarify? I can help you find a recipe, give cooking advice, or answer nutrition questions.";
        }

        // ── STEP 3: RESPOND + CACHE ───────────────────────────────────────
        const payload = { type: intent, reply: finalReply, recipes: finalRecipes };

        if (!currentRecipeId) cacheSet(cacheKey, payload);

        const totalMs = Date.now() - t0;
        console.log(`[chat] done  intent:${intent}  total:${totalMs}ms`);
        qualityLogger.log({ intent, message, reply: finalReply, ms: totalMs });
        res.status(200).json(payload);

    } catch (error) {
        console.error('[chat] error:', error.message || error);
        res.status(500).json({ error: 'Foodie AI is currently offline.' });
    }
};
