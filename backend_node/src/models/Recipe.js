const mongoose = require('mongoose');

const RecipeSchema = new mongoose.Schema({
    recipe_name: { type: String, required: true },
    prep_time: { type: String },
    cook_time: { type: String },
    total_time: { type: String },
    servings: { type: Number },
    yield: { type: String },
    ingredients: [{ type: String }], // Storing as an array of strings
    directions: { type: String },
    rating: { type: Number },
    url: { type: String },
    cuisine_path: { type: String },
    nutrition: { type: String },
    timing: { type: String },
    img_src: { type: String },
    
    // Precomputed fields for the AI / filtering engine
    allergenTags: [{ type: String }], 
    dietTags: [{ type: String }]
}, { timestamps: true });

module.exports = mongoose.model('Recipe', RecipeSchema);