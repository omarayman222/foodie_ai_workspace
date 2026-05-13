const ShoppingList = require('../models/ShoppingList');

exports.addToList = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { items } = req.body; // We expect an array of strings from the frontend

        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({ error: "Please provide an array of items to add." });
        }

        // 1. Find the user's list, or create an empty one if they are a new user
        let shoppingList = await ShoppingList.findOne({ userId });
        if (!shoppingList) {
            shoppingList = new ShoppingList({ userId, items: [] });
        }

        // 2. The Smart Aggregation Loop
        items.forEach(newItemName => {
            const cleanName = newItemName.toLowerCase().trim();
            
            // Check if this exact item is already in the database array
            const existingItemIndex = shoppingList.items.findIndex(
                item => item.name.toLowerCase() === cleanName
            );

            if (existingItemIndex > -1) {
                // Item exists! Just increment the quantity to prevent duplicates
                shoppingList.items[existingItemIndex].quantity += 1;
            } else {
                // New item! Push it to the array with a default quantity of 1
                shoppingList.items.push({ name: cleanName, quantity: 1 });
            }
        });

        // 3. Save the updated list to MongoDB
        await shoppingList.save();

        res.status(200).json({ 
            message: "Items successfully added to your Smart Shopping List!", 
            shoppingList 
        });

    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Failed to update shopping list." });
    }
};

exports.removeFromList = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { items } = req.body; // Expecting an array of strings to remove

        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({ error: "Please provide an array of items to remove." });
        }

        // 1. Find the user's list
        const shoppingList = await ShoppingList.findOne({ userId });
        
        if (!shoppingList) {
            return res.status(404).json({ error: "Shopping list not found." });
        }

        // 2. The Smart Decrement/Delete Loop
        items.forEach(itemToRemove => {
            const cleanName = itemToRemove.toLowerCase().trim();
            
            // Find where this item lives in the array
            const existingItemIndex = shoppingList.items.findIndex(
                item => item.name.toLowerCase() === cleanName
            );

            // If the item actually exists on the list
            if (existingItemIndex > -1) {
                const currentItem = shoppingList.items[existingItemIndex];

                if (currentItem.quantity > 1) {
                    // If they have more than 1, just decrement the math
                    currentItem.quantity -= 1;
                } else {
                    // If they only have 1 left, completely erase it from the array
                    shoppingList.items.splice(existingItemIndex, 1);
                }
            }
        });

        // 3. Save the updated list to MongoDB
        await shoppingList.save();

        res.status(200).json({ 
            message: "Items successfully removed from your list!", 
            shoppingList 
        });

    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Failed to remove items from shopping list." });
    }
};
// --- NEW FUNCTION 1: Fetch the list for the UI ---
exports.getList = async (req, res) => {
    try {
        const userId = req.user.userId;
        let shoppingList = await ShoppingList.findOne({ userId });
        
        if (!shoppingList) {
            shoppingList = { items: [] }; // Return empty if none exists
        }

        res.status(200).json(shoppingList);
    } catch (error) {
        res.status(500).json({ error: "Failed to fetch shopping list." });
    }
};

// --- NEW FUNCTION 2: Automated Recipe Gap Analysis ---
const GROCERY_PROMPT = `
You are an intelligent grocery list assistant. 
I will give you a list of ingredients required for a recipe, and a list of items the user already has in their pantry.
Your job is to figure out which ingredients are MISSING, and generate a shopping list.

Group the missing items into logical supermarket categories (e.g., "Produce", "Dairy", "Meat", "Pantry Staples", "Spices").
Simplify the item names (e.g., turn "2 cups finely diced red onion" into just "Red Onion").

You MUST return ONLY a valid JSON object in this exact format:
{
  "missing_items": [
    {
      "name": "Red Onion",
      "quantity": 1,
      "category": "Produce"
    }
  ]
}
If the user already has everything, return an empty array.
`;

exports.generateFromRecipe = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { recipeId } = req.body;

        // 1. Fetch User (for pantry) and Recipe (for ingredients)
        const user = await User.findById(userId);
        const recipe = await Recipe.findById(recipeId);

        if (!user || !recipe) {
            return res.status(404).json({ error: "User or Recipe not found." });
        }

        const userPrompt = `
        Recipe Ingredients Needed: ${recipe.ingredients.join(', ')}
        User's Current Pantry: ${user.pantry.join(', ')}
        `;

        // 2. Ask Groq to find the missing items and categorize them
        const chatCompletion = await groq.chat.completions.create({
            messages: [
                { role: "system", content: GROCERY_PROMPT },
                { role: "user", content: userPrompt }
            ],
            model: "llama-3.1-8b-instant",
            temperature: 0.1, 
            response_format: { type: "json_object" }
        });

        const aiResponse = JSON.parse(chatCompletion.choices[0].message.content);
        const newItems = aiResponse.missing_items || [];

        // 3. Save to the database
        if (newItems.length > 0) {
            let shoppingList = await ShoppingList.findOne({ userId });
            if (!shoppingList) {
                shoppingList = new ShoppingList({ userId, items: [] });
            }

            newItems.forEach(aiItem => {
                const cleanName = aiItem.name.toLowerCase().trim();
                const existingItemIndex = shoppingList.items.findIndex(
                    item => item.name.toLowerCase() === cleanName
                );

                if (existingItemIndex > -1) {
                    shoppingList.items[existingItemIndex].quantity += (aiItem.quantity || 1);
                } else {
                    shoppingList.items.push({ 
                        name: cleanName, 
                        quantity: aiItem.quantity || 1,
                        category: aiItem.category || "Uncategorized" // Fulfills the categorization requirement!
                    });
                }
            });

            await shoppingList.save();
            return res.status(200).json({ 
                message: "Automated list generated!", 
                shoppingList 
            });
        }

        res.status(200).json({ message: "You already have all the ingredients!" });

    } catch (error) {
        console.error("Grocery Generation Error:", error);
        res.status(500).json({ error: "Failed to generate grocery list." });
    }
};