require('dotenv').config();
const mongoose = require('mongoose');
const fs = require('fs');
const csv = require('csv-parser');
const Recipe = require('./src/models/Recipe'); // Your Recipe schema

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URI)
    .then(() => console.log('✅ Connected to MongoDB for seeding...'))
    .catch(err => console.error('Connection error:', err));

const recipes = [];

// Read the CSV file
fs.createReadStream('recipes2.csv')
    .pipe(csv())
    .on('data', (row) => {
        // Map the CSV columns to our Mongoose schema
        const recipe = {
            recipe_name: row.recipe_name,
            prep_time: row.prep_time,
            cook_time: row.cook_time,
            total_time: row.total_time,
            servings: parseInt(row.servings) || 0,
            yield: row.yield,
            // The dataset has ingredients as one long string. We split it into an array here.
            ingredients: row.ingredients ? row.ingredients.split(',').map(i => i.trim()) : [],
            directions: row.directions,
            rating: parseFloat(row.rating) || 0,
            url: row.url,
            cuisine_path: row.cuisine_path,
            nutrition: row.nutrition,
            timing: row.timing,
            img_src: row.img_src,
            allergenTags: [], // We leave this empty for now
            dietTags: []      // We leave this empty for now
        };
        recipes.push(recipe);
    })
    .on('end', async () => {
        console.log(`CSV file successfully processed. Found ${recipes.length} recipes.`);
        try {
            // Clear out any old recipes just in case you run this script twice
            await Recipe.deleteMany({});
            console.log('🧹 Cleared out old recipe data.');
            
            // Insert all the new recipes at once
            await Recipe.insertMany(recipes);
            console.log('🚀 Successfully seeded the database with all recipes!');
            
            // Close the script
            process.exit();
        } catch (error) {
            console.error('❌ Error seeding database:', error);
            process.exit(1);
        }
    });