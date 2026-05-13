const express = require('express');
const router = express.Router();
const ratingController = require('../controllers/ratingController');
const authMiddleware = require('../middleware/authMiddleware');

// Route: POST /api/ratings
router.post('/', authMiddleware, ratingController.rateRecipe);

module.exports = router;