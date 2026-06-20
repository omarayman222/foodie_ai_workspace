const Groq = require('groq-sdk');
const ShoppingList = require('../models/ShoppingList');
const Pantry = require('../models/Pantry');
const Recipe = require('../models/Recipe');
const User = require('../models/User');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ── GET /api/shopping-list ─────────────────────────────────────
exports.getList = async (req, res) => {
    try {
        const userId = req.user.userId;
        let shoppingList = await ShoppingList.findOne({ userId });
        if (!shoppingList) shoppingList = { items: [] };
        res.status(200).json(shoppingList);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch shopping list.' });
    }
};

// ── POST /api/shopping-list/add ────────────────────────────────
exports.addToList = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { items } = req.body;

        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({ error: 'Please provide an array of items to add.' });
        }

        let shoppingList = await ShoppingList.findOne({ userId });
        if (!shoppingList) shoppingList = new ShoppingList({ userId, items: [] });

        items.forEach(newItemName => {
            const cleanName = newItemName.toLowerCase().trim();
            const idx = shoppingList.items.findIndex(i => i.name.toLowerCase() === cleanName);
            if (idx > -1) {
                shoppingList.items[idx].quantity += 1;
            } else {
                shoppingList.items.push({ name: cleanName, quantity: 1 });
            }
        });

        await shoppingList.save();
        res.status(200).json({ message: 'Items added to shopping list!', shoppingList });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to update shopping list.' });
    }
};

// ── POST /api/shopping-list/remove ────────────────────────────
exports.removeFromList = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { items } = req.body;

        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({ error: 'Please provide an array of items to remove.' });
        }

        const shoppingList = await ShoppingList.findOne({ userId });
        if (!shoppingList) return res.status(404).json({ error: 'Shopping list not found.' });

        items.forEach(itemToRemove => {
            const cleanName = itemToRemove.toLowerCase().trim();
            const idx = shoppingList.items.findIndex(i => i.name.toLowerCase() === cleanName);
            if (idx > -1) {
                if (shoppingList.items[idx].quantity > 1) {
                    shoppingList.items[idx].quantity -= 1;
                } else {
                    shoppingList.items.splice(idx, 1);
                }
            }
        });

        await shoppingList.save();
        res.status(200).json({ message: 'Items removed from list!', shoppingList });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to remove items from shopping list.' });
    }
};

// ── PATCH /api/shopping-list/check/:itemId ─────────────────────
exports.checkItem = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { itemId } = req.params;

        const shoppingList = await ShoppingList.findOne({ userId });
        if (!shoppingList) return res.status(404).json({ error: 'Shopping list not found.' });

        const item = shoppingList.items.id(itemId);
        if (!item) return res.status(404).json({ error: 'Item not found.' });

        const nowChecked = !item.isChecked;
        item.isChecked = nowChecked;
        await shoppingList.save();

        // Auto-sync: add to pantry when checked on
        if (nowChecked) {
            let pantry = await Pantry.findOne({ userId });
            if (!pantry) pantry = new Pantry({ userId, items: [], ingredients: [] });
            if (!pantry.items.some(i => i.name.toLowerCase() === item.name.toLowerCase())) {
                pantry.items.push({ name: item.name });
                pantry.ingredients = pantry.items.map(i => i.name);
                await pantry.save();
            }
        }

        res.status(200).json({ isChecked: item.isChecked, shoppingList });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to toggle item.' });
    }
};

// ── POST /api/shopping-list/move-to-pantry ────────────────────
// Kept for any direct callers; internally reuses checkItem logic
exports.moveToPantry = async (req, res) => {
    try {
        const userId = req.user.userId;

        const shoppingList = await ShoppingList.findOne({ userId });
        if (!shoppingList) return res.status(404).json({ error: 'Shopping list not found.' });

        const checked = shoppingList.items.filter(i => i.isChecked);
        if (checked.length === 0) {
            return res.status(200).json({ message: 'No checked items to move.', moved: 0, shoppingList });
        }

        const names = checked.map(i => i.name);

        let pantry = await Pantry.findOne({ userId });
        if (!pantry) pantry = new Pantry({ userId, items: [], ingredients: [] });

        for (const name of names) {
            if (!pantry.items.some(i => i.name.toLowerCase() === name.toLowerCase())) {
                pantry.items.push({ name });
            }
        }
        pantry.ingredients = pantry.items.map(i => i.name);
        await pantry.save();

        shoppingList.items = shoppingList.items.filter(i => !i.isChecked);
        await shoppingList.save();

        res.status(200).json({
            message: `${names.length} item(s) moved to pantry!`,
            moved: names.length,
            shoppingList,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to move items to pantry.' });
    }
};

// ── POST /api/shopping-list/generate ──────────────────────────
const GROCERY_PROMPT = `You are an intelligent grocery list assistant.
Given the recipe ingredients needed and what the user already has in their pantry,
output ONLY the missing items as valid JSON in this exact format:
{
  "missing_items": [
    { "name": "Red Onion", "quantity": 1, "category": "Produce" }
  ]
}
Simplify item names (e.g. "2 cups finely diced red onion" → "Red Onion").
Group into supermarket categories: Produce, Dairy, Meat, Pantry Staples, Spices, Bakery, Frozen, Other.
If the user already has everything, return { "missing_items": [] }.`;

exports.generateFromRecipe = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { recipeId, ingredients: fallbackIngredients } = req.body;

        // Fetch pantry and recipe in parallel (recipe lookup is optional — use fallback)
        const [pantry, recipe] = await Promise.all([
            Pantry.findOne({ userId }),
            recipeId ? Recipe.findById(recipeId).catch(() => null) : Promise.resolve(null),
        ]);

        // Resolve recipe ingredients: prefer DB, fall back to client-sent list
        const recipeIngredients =
            recipe?.ingredients?.length
                ? recipe.ingredients
                : Array.isArray(fallbackIngredients) && fallbackIngredients.length
                    ? fallbackIngredients
                    : null;

        if (!recipeIngredients) {
            return res.status(400).json({ error: 'Could not resolve recipe ingredients.' });
        }

        // Resolve pantry items (filter expired)
        const now = new Date();
        const pantryItems = pantry?.items?.length
            ? pantry.items.filter(i => !i.expiryDate || new Date(i.expiryDate) >= now).map(i => i.name)
            : (pantry?.ingredients || []);

        const userPrompt = `Recipe Ingredients Needed: ${recipeIngredients.join(', ')}\nUser's Pantry: ${pantryItems.join(', ') || 'empty'}`;

        const chatCompletion = await groq.chat.completions.create({
            messages: [
                { role: 'system', content: GROCERY_PROMPT },
                { role: 'user', content: userPrompt },
            ],
            model: 'llama-3.1-8b-instant',
            temperature: 0.1,
            response_format: { type: 'json_object' },
        });

        let aiResponse;
        try {
            aiResponse = JSON.parse(chatCompletion.choices[0].message.content);
        } catch (_) {
            aiResponse = { missing_items: [] };
        }

        const newItems = aiResponse.missing_items || [];

        if (newItems.length === 0) {
            return res.status(200).json({ message: 'You already have all the ingredients!', shoppingList: null });
        }

        let shoppingList = await ShoppingList.findOne({ userId });
        if (!shoppingList) shoppingList = new ShoppingList({ userId, items: [] });

        newItems.forEach(aiItem => {
            const cleanName = (aiItem.name || '').toLowerCase().trim();
            if (!cleanName) return;
            const idx = shoppingList.items.findIndex(i => i.name.toLowerCase() === cleanName);
            if (idx > -1) {
                shoppingList.items[idx].quantity += (aiItem.quantity || 1);
            } else {
                shoppingList.items.push({
                    name: cleanName,
                    quantity: aiItem.quantity || 1,
                    category: aiItem.category || 'Uncategorized',
                });
            }
        });

        await shoppingList.save();
        res.status(200).json({ message: `${newItems.length} missing ingredient(s) added to your shopping list!`, shoppingList });

    } catch (error) {
        console.error('Grocery Generation Error:', error);
        res.status(500).json({ error: 'Failed to generate grocery list.' });
    }
};
