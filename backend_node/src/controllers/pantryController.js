const Pantry = require('../models/Pantry');

// Helper: keep the legacy `ingredients` string-array in sync so the AI engine keeps working
function syncLegacy(pantry) {
    pantry.ingredients = (pantry.items || []).map(i => i.name);
}

exports.getPantry = async (req, res) => {
    try {
        const userId = req.user.userId;
        let pantry = await Pantry.findOne({ userId });

        if (!pantry) return res.status(200).json({ items: [], ingredients: [] });

        // Migrate old string-only pantries on first access
        if (pantry.items.length === 0 && pantry.ingredients.length > 0) {
            pantry.items = pantry.ingredients.map(name => ({ name, expiryDate: null }));
            await pantry.save();
        }

        res.status(200).json({
            items: pantry.items,
            ingredients: pantry.ingredients,
        });
    } catch (e) {
        res.status(500).json({ error: 'Failed to fetch pantry.' });
    }
};

exports.addIngredients = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { ingredients } = req.body; // legacy: array of strings

        if (!ingredients || !Array.isArray(ingredients)) {
            return res.status(400).json({ error: 'Please provide an array of ingredients.' });
        }

        let pantry = await Pantry.findOne({ userId });
        if (!pantry) pantry = new Pantry({ userId, items: [], ingredients: [] });

        for (const name of ingredients) {
            if (!pantry.items.some(i => i.name.toLowerCase() === name.toLowerCase())) {
                pantry.items.push({ name });
            }
        }
        syncLegacy(pantry);
        await pantry.save();

        res.status(200).json({ message: 'Pantry updated!', pantry });
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Failed to update pantry.' });
    }
};

// Full overwrite — accepts { items: [{name, expiryDate?, quantity?}] }
// Also still accepts legacy { ingredients: [string] } for backward compat
exports.overwritePantry = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { items, ingredients } = req.body;

        let newItems = [];
        if (items && Array.isArray(items)) {
            newItems = items.map(i => ({
                name: i.name || i,
                expiryDate: i.expiryDate ? new Date(i.expiryDate) : null,
                quantity: i.quantity || '',
            }));
        } else if (ingredients && Array.isArray(ingredients)) {
            newItems = ingredients.map(name => ({ name, expiryDate: null, quantity: '' }));
        } else {
            return res.status(400).json({ error: 'Provide items or ingredients array.' });
        }

        let pantry = await Pantry.findOne({ userId });
        if (!pantry) pantry = new Pantry({ userId, items: [], ingredients: [] });

        pantry.items = newItems;
        syncLegacy(pantry);
        await pantry.save();

        res.status(200).json({ message: 'Pantry saved!', pantry });
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Failed to save pantry.' });
    }
};
