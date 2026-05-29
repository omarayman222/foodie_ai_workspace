const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const authMiddleware = require('../middleware/authMiddleware');

// The single unified chat endpoint
router.post('/', authMiddleware, chatController.processChat);

module.exports = router;