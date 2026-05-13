const mongoose = require('mongoose');

// We define the structure for a single item first
const shoppingListItemSchema = new mongoose.Schema({
    name: { 
        type: String, 
        required: true 
    },
    quantity: { 
        type: Number, 
        default: 1 
    },
    category: { 
        type: String, 
        default: 'Uncategorized' 
    },
    isChecked: { 
        type: Boolean, 
        default: false 
    }
});

// Then we attach an array of those items to a specific user
const shoppingListSchema = new mongoose.Schema({
    userId: { 
        type: mongoose.Schema.Types.ObjectId, 
        ref: 'User', 
        required: true, 
        unique: true // One shopping list per user!
    },
    items: [shoppingListItemSchema]
}, { timestamps: true });

module.exports = mongoose.model('ShoppingList', shoppingListSchema);