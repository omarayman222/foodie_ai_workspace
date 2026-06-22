const mongoose = require('mongoose');

// Single-document settings store — always upsert the one document
const SettingsSchema = new mongoose.Schema({
    emailUser: { type: String, default: '' },
    emailPass: { type: String, default: '' },
}, { timestamps: true });

module.exports = mongoose.model('Settings', SettingsSchema);
