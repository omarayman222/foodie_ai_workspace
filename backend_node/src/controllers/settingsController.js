const Settings = require('../models/Settings');

// GET /api/settings/email-config
// Returns the configured sender email (password is never sent to client)
exports.getEmailConfig = async (req, res) => {
    try {
        const s = await Settings.findOne();
        res.json({
            emailUser: s?.emailUser || '',
            configured: !!(s?.emailUser && s?.emailPass),
        });
    } catch (err) {
        res.status(500).json({ error: 'Failed to load email config' });
    }
};

// POST /api/settings/email-config
// Saves sender email + app password to DB
exports.updateEmailConfig = async (req, res) => {
    try {
        const { emailUser, emailPass } = req.body;
        if (!emailUser || !emailPass) {
            return res.status(400).json({ error: 'Both email and password are required.' });
        }
        await Settings.findOneAndUpdate(
            {},
            { emailUser: emailUser.trim(), emailPass: emailPass.trim() },
            { upsert: true, new: true }
        );
        res.json({ message: 'Email configuration saved.' });
    } catch (err) {
        res.status(500).json({ error: 'Failed to save email config' });
    }
};
