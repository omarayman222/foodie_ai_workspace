const express = require('express');
const router = express.Router();
const pantryController = require('../controllers/pantryController');
const authMiddleware = require('../middleware/authMiddleware');

// Route to add ingredients to the pantry
router.post('/add', authMiddleware, pantryController.addIngredients);

// NEW route to REPLACE items
router.put('/update', authMiddleware, pantryController.overwritePantry);

module.exports = router;