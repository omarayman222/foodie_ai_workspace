const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    profile: {
        allergies: [{ type: String }],
        diet: [{ type: String }],
        medicalConditions: [{ type: String }], // NEW
        dislikes: [{ type: String }],          // NEW
        dislikedCuisines: [{ type: String }]   // NEW
    }
}, { timestamps: true });

module.exports = mongoose.model('User', UserSchema);