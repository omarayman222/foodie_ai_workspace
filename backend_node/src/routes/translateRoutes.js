const express = require('express');
const router = express.Router();
const translationController = require('../controllers/translationController');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/', authMiddleware, translationController.translate);

module.exports = router;
