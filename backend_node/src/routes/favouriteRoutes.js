const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/favouriteController');
const auth = require('../middleware/authMiddleware');

router.get('/',                     auth, ctrl.getFavourites);
router.post('/',                    auth, ctrl.addFavourite);
router.delete('/:recipeId',         auth, ctrl.removeFavourite);
router.get('/check/:recipeId',      auth, ctrl.checkFavourite);

module.exports = router;
