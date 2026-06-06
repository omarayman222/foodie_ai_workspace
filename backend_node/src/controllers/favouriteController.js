const Favourite = require('../models/Favourite');

exports.getFavourites = async (req, res) => {
    try {
        const favs = await Favourite.find({ userId: req.user.userId }).sort({ createdAt: -1 });
        res.json({ favourites: favs });
    } catch (e) {
        res.status(500).json({ error: 'Failed to fetch favourites' });
    }
};

exports.addFavourite = async (req, res) => {
    try {
        const { recipeId, recipeName, recipeImage, prepTime, totalTime, servings, cuisine } = req.body;
        if (!recipeId) return res.status(400).json({ error: 'recipeId is required' });

        const fav = await Favourite.findOneAndUpdate(
            { userId: req.user.userId, recipeId },
            { userId: req.user.userId, recipeId, recipeName, recipeImage, prepTime, totalTime, servings, cuisine },
            { upsert: true, new: true }
        );
        res.json({ success: true, favourite: fav });
    } catch (e) {
        res.status(500).json({ error: 'Failed to add favourite' });
    }
};

exports.removeFavourite = async (req, res) => {
    try {
        await Favourite.deleteOne({ userId: req.user.userId, recipeId: req.params.recipeId });
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ error: 'Failed to remove favourite' });
    }
};

exports.checkFavourite = async (req, res) => {
    try {
        const fav = await Favourite.findOne({ userId: req.user.userId, recipeId: req.params.recipeId });
        res.json({ isFavourite: !!fav });
    } catch (e) {
        res.status(500).json({ error: 'Failed to check favourite' });
    }
};
