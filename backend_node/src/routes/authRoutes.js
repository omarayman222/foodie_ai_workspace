const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// Route to register a new user
router.post('/register', authController.register);

// Route to log in an existing user
router.post('/login', authController.login);

module.exports = router;