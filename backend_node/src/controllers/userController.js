const User = require('../models/User');

exports.getProfile = async (req, res) => {
    try {
        const user = await User.findById(req.user.userId);
        if (!user) return res.status(404).json({ error: 'User not found.' });

        res.status(200).json({
            email: user.email,
            name: user.profile.name || user.name || '',
            profile: {
                name:              user.profile.name              ?? '',
                allergies:         user.profile.allergies         ?? [],
                diet:              user.profile.diet              ?? [],
                medicalConditions: user.profile.medicalConditions ?? [],
                dislikes:          user.profile.dislikes          ?? [],
                dislikedCuisines:  user.profile.dislikedCuisines  ?? [],
            },
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch profile.' });
    }
};

exports.updateProfile = async (req, res) => {
    try {
        const user = await User.findById(req.user.userId);
        if (!user) return res.status(404).json({ error: 'User not found.' });

        const { name, allergies, diet, medicalConditions, dislikes, dislikedCuisines } = req.body;

        if (name !== undefined) {
            user.profile.name = String(name).trim();
            user.name = user.profile.name;
        }
        if (Array.isArray(allergies))         user.profile.allergies         = allergies;
        if (Array.isArray(diet))              user.profile.diet              = diet;
        if (Array.isArray(medicalConditions)) user.profile.medicalConditions = medicalConditions;
        if (Array.isArray(dislikes))          user.profile.dislikes          = dislikes;
        if (Array.isArray(dislikedCuisines))  user.profile.dislikedCuisines  = dislikedCuisines;

        await user.save();

        res.status(200).json({
            message: 'Profile updated successfully!',
            profile: {
                name:              user.profile.name,
                allergies:         user.profile.allergies,
                diet:              user.profile.diet,
                medicalConditions: user.profile.medicalConditions,
                dislikes:          user.profile.dislikes,
                dislikedCuisines:  user.profile.dislikedCuisines,
            },
        });
    } catch (error) {
        console.error('updateProfile error:', error);
        res.status(500).json({ error: 'Failed to update profile.' });
    }
};
