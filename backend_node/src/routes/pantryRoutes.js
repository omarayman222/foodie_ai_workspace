const express = require('express');
const router = express.Router();
const pantryController = require('../controllers/pantryController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/', authMiddleware, pantryController.getPantry);
router.post('/add', authMiddleware, pantryController.addIngredients);

// NEW route to REPLACE items
router.put('/update', authMiddleware, pantryController.overwritePantry);

module.exports = router;