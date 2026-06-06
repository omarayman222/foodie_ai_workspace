const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/mealPlanController');
const auth = require('../middleware/authMiddleware');

router.get('/', auth, ctrl.getMealPlan);

module.exports = router;
