const mongoose = require('mongoose');

const FavouriteSchema = new mongoose.Schema({
    userId:      { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    recipeId:    { type: String, required: true },
    recipeName:  { type: String, default: '' },
    recipeImage: { type: String, default: '' },
    prepTime:    { type: String, default: '' },
    cookTime:    { type: String, default: '' },
    totalTime:   { type: String, default: '' },
    servings:    { type: String, default: '' },
    cuisine:     { type: String, default: '' },
    rating:      { type: Number, default: 0 },
    nutrition:   { type: String, default: '' },
    ingredients: [{ type: String }],
    directions:  { type: String, default: '' },
}, { timestamps: true });

FavouriteSchema.index({ userId: 1, recipeId: 1 }, { unique: true });

module.exports = mongoose.model('Favourite', FavouriteSchema);
