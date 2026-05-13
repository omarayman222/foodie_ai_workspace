const User = require('../models/User');

exports.updateProfile = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { allergies, diet, medicalConditions, dislikes, dislikedCuisines } = req.body;

        // 1. Find the user in the database
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ error: "User not found." });
        }

        // 2. Update their allergies
        if (allergies && Array.isArray(allergies)) {
            user.profile.allergies = allergies;
        }

        // 3. Update their diet preferences
        if (diet && Array.isArray(diet)) {
            user.profile.diet = diet;
        }

        if (medicalConditions && Array.isArray(medicalConditions)){
             user.profile.medicalConditions = medicalConditions;
        }

        if (dislikes && Array.isArray(dislikes)){
             user.profile.dislikes = dislikes;
        }
        if (dislikedCuisines && Array.isArray(dislikedCuisines)) {
            user.profile.dislikedCuisines = dislikedCuisines;
        }

        // 4. Save the updated user
        await user.save();

        res.status(200).json({ 
            message: "Profile updated successfully!", 
            profile: user.profile 
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Failed to update profile." });
    }
};