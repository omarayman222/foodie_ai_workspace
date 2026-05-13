const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const authMiddleware = require('../middleware/authMiddleware');

// Route: POST /api/chat
router.post('/', authMiddleware, chatController.handleChat);

module.exports = router;