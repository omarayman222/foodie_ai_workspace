const express = require('express');
const router = express.Router();
const recipeController = require('../controllers/recipeController');
const authMiddleware = require('../middleware/authMiddleware');

// Notice how we put authMiddleware in the middle? 
// That acts as the bouncer checking for the VIP wristband!
router.get('/recommendations', authMiddleware, recipeController.getRecommendations);
router.get('/search',          authMiddleware, recipeController.searchRecipes);

module.exports = router;