const express = require('express');
const router = express.Router();
const shoppingListController = require('../controllers/shoppingListController');
const authMiddleware = require('../middleware/authMiddleware');


// Get the user's current list
router.get('/', authMiddleware, shoppingListController.getList);
// Route: POST /api/shopping-list/add
router.post('/add', authMiddleware, shoppingListController.addToList);

// Route: POST /api/shopping-list/remove
router.post('/remove', authMiddleware, shoppingListController.removeFromList);

// Feature 6.7: Automated List Generation
router.post('/generate', authMiddleware, shoppingListController.generateFromRecipe);

module.exports = router;