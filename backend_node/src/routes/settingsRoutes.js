const express = require('express');
const router = express.Router();
const { getEmailConfig, updateEmailConfig } = require('../controllers/settingsController');

router.get('/email-config',  getEmailConfig);
router.post('/email-config', updateEmailConfig);

module.exports = router;
