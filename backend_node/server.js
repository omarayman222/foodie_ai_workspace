require('dotenv').config();
const express    = require('express');
const mongoose   = require('mongoose');
const cors       = require('cors');
const compression = require('compression');

// Initialize the Express app
const app = express();

// Middleware
app.use(compression()); // gzip all responses
app.use(cors());
app.use(express.json());

// Import and use our new auth routes
const authRoutes = require('./src/routes/authRoutes');
app.use('/api/auth', authRoutes);

// Import and use our recipe routes (which include the recommendations endpoint)
const recipeRoutes = require('./src/routes/recipeRoutes');
app.use('/api/recipes', recipeRoutes);

// Import and use our pantry routes
const pantryRoutes = require('./src/routes/pantryRoutes');
app.use('/api/pantry', pantryRoutes);

// Import and use our user routes (for profile updates, etc.)
const userRoutes = require('./src/routes/userRoutes');
app.use('/api/users', userRoutes);

// Import and use our shopping list routes
const shoppingListRoutes = require('./src/routes/shoppingListRoutes');
app.use('/api/shopping-list', shoppingListRoutes);

// Import and use our chat routes (for AI interactions)
const chatRoutes = require('./src/routes/chatRoutes');
app.use('/api/chat', chatRoutes);

// Import and use our rating routes (for recipe ratings and feedback)
const ratingRoutes = require('./src/routes/ratingRoutes');
app.use('/api/ratings', ratingRoutes);

const substitutionRoutes = require('./src/routes/substitutionRoutes');
app.use('/api/substitutions', substitutionRoutes);

const cookingRoutes = require('./src/routes/cookingRoutes');
app.use('/api/cook', cookingRoutes);

const favouriteRoutes = require('./src/routes/favouriteRoutes');
app.use('/api/favourites', favouriteRoutes);

const mealPlanRoutes = require('./src/routes/mealPlanRoutes');
app.use('/api/meal-plan', mealPlanRoutes);

const recommendationRoutes = require('./src/routes/recommendationRoutes');
app.use('/api/recommendations', recommendationRoutes);

const translateRoutes = require('./src/routes/translateRoutes');
app.use('/api/translate', translateRoutes);

const settingsRoutes = require('./src/routes/settingsRoutes');
app.use('/api/settings', settingsRoutes);

// Basic Test Route
app.get('/', (req, res) => {
    res.json({ message: "Welcome to the FoodieAI Backend API! 🍳" });
});

// Database Connection
const PORT = process.env.PORT || 5000;
const MONGO_URI = process.env.MONGO_URI;

mongoose.connect(MONGO_URI)
    .then(() => {
        console.log('✅ Connected to MongoDB successfully!');
        // Start the server only after connecting to the database
        app.listen(PORT, () => {
            console.log(`🚀 Server is running on http://localhost:${PORT}`);
        });
    })
    .catch((error) => {
        console.error('❌ MongoDB connection error:', error.message);
    });