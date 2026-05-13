const express = require('express');
const router = express.Router();
const cookingController = require('../controllers/cookingController');
const authMiddleware = require('../middleware/authMiddleware');

// Route: POST /api/cook
// This hits the sousChefChat function we just built!
router.post('/', authMiddleware, cookingController.sousChefChat);

module.exports = router;