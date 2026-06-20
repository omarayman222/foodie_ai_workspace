const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/shoppingListController');
const auth = require('../middleware/authMiddleware');

router.get('/',                  auth, ctrl.getList);
router.post('/add',              auth, ctrl.addToList);
router.post('/remove',           auth, ctrl.removeFromList);
router.patch('/check/:itemId',   auth, ctrl.checkItem);
router.post('/move-to-pantry',   auth, ctrl.moveToPantry);
router.post('/generate',         auth, ctrl.generateFromRecipe);

module.exports = router;
