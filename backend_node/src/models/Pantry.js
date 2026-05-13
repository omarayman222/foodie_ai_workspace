const mongoose = require('mongoose');

const PantrySchema = new mongoose.Schema({
    userId: { 
        type: mongoose.Schema.Types.ObjectId, 
        ref: 'User', 
        required: true 
    },
    ingredients: [{ type: String }] // Array of standardized ingredient names
}, { timestamps: true });

module.exports = mongoose.model('Pantry', PantrySchema);