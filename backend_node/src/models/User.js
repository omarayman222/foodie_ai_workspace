const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    name:     { type: String, default: '' },
    email:    { type: String, required: true, unique: true },
    password: { type: String, required: true },
    profile: {
        name:              { type: String, default: '' },
        allergies:         [{ type: String }],
        diet:              [{ type: String }],
        medicalConditions: [{ type: String }],
        dislikes:          [{ type: String }],
        dislikedCuisines:  [{ type: String }],
    }
}, { timestamps: true });

module.exports = mongoose.model('User', UserSchema);
