const mongoose = require('mongoose');

const PantryItemSchema = new mongoose.Schema({
    name:       { type: String, required: true },
    expiryDate: { type: Date,   default: null  },
    quantity:   { type: String, default: ''    },
}, { _id: false });

const PantrySchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    items:       [PantryItemSchema],  // new rich format
    ingredients: [{ type: String }],  // legacy — kept for the AI engine query path
}, { timestamps: true });

module.exports = mongoose.model('Pantry', PantrySchema);
