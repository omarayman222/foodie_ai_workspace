const Pantry = require('../models/Pantry');

exports.addIngredients = async (req, res) => {
    try {
        const userId = req.user.userId; // We get this from the authMiddleware!
        const { ingredients } = req.body; // We expect an array like ["chicken", "rice"]

        if (!ingredients || !Array.isArray(ingredients)) {
            return res.status(400).json({ error: "Please provide an array of ingredients." });
        }

        // 1. Look for the user's existing pantry
        let pantry = await Pantry.findOne({ userId });

        if (pantry) {
            // 2a. If they have a pantry, add new items (and prevent duplicates)
            const combinedIngredients = [...pantry.ingredients, ...ingredients];
            pantry.ingredients = [...new Set(combinedIngredients)]; 
            await pantry.save();
        } else {
            // 2b. If they don't have a pantry yet, create one!
            pantry = new Pantry({
                userId: userId,
                ingredients: ingredients
            });
            await pantry.save();
        }

        res.status(200).json({ message: "Pantry updated successfully!", pantry });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Failed to update pantry." });
    }
};

// NEW: Function to completely overwrite the pantry
exports.overwritePantry = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { ingredients } = req.body; 

        if (!ingredients || !Array.isArray(ingredients)) {
            return res.status(400).json({ error: "Please provide an array of ingredients." });
        }

        let pantry = await Pantry.findOne({ userId });

        if (pantry) {
            // Simply replace the old array with the new one
            pantry.ingredients = ingredients; 
            await pantry.save();
        } else {
            pantry = new Pantry({
                userId: userId,
                ingredients: ingredients
            });
            await pantry.save();
        }

        res.status(200).json({ message: "Pantry overwritten successfully!", pantry });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Failed to overwrite pantry." });
    }
};