const express = require('express');
const router = express.Router();
const substitutionController = require('../controllers/substitutionController');
const authMiddleware = require('../middleware/authMiddleware');

// Route: POST /api/substitutions
router.post('/', authMiddleware, substitutionController.getSubstitution);

module.exports = router;