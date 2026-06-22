const User = require('../models/User');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { generateAndSendOtp, verifyOtp, checkOtp, verifyOtpAndAccount } = require('../services/otpService');

// ── Register ──────────────────────────────────────────────────────────────
exports.register = async (req, res) => {
    try {
        const { name = '', email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required.' });
        }
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);
        const newUser = new User({
            name,
            email,
            password: hashedPassword,
            profile: { name, allergies: [], diet: [], medicalConditions: [], dislikes: [], dislikedCuisines: [] },
        });
        await newUser.save();
        res.status(201).json({ message: 'User registered successfully!', userId: newUser._id });
    } catch (error) {
        if (error.code === 11000) {
            return res.status(400).json({ error: 'An account with this email already exists.' });
        }
        res.status(500).json({ error: 'Failed to register user', details: error.message });
    }
};

// ── Login ─────────────────────────────────────────────────────────────────
exports.login = async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required.' });
        }
        const user = await User.findOne({ email });
        if (!user) return res.status(400).json({ error: 'Invalid email or password' });
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(400).json({ error: 'Invalid email or password' });
        const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.status(200).json({
            message: 'Login successful!',
            token,
            userId: user._id,
            name: user.profile.name || user.name || '',
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to log in', details: error.message });
    }
};

// ── Forgot Password — send OTP via EmailJS ────────────────────────────────
exports.forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) return res.status(400).json({ error: 'Email is required.' });

        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ error: 'No account found with this email.' });

        const userName = user.profile?.name || user.name || email.split('@')[0];
        await generateAndSendOtp(email, userName);

        res.status(200).json({ message: 'OTP sent to your email.' });
    } catch (error) {
        console.error('[forgotPassword]', error.message);
        res.status(500).json({ error: `Failed to send OTP: ${error.message}` });
    }
};

// ── Check OTP — validate without consuming (step 2 gate) ─────────────────
exports.checkOtp = (req, res) => {
    const { email, otp } = req.body;
    if (!email || !otp) return res.status(400).json({ error: 'Email and OTP are required.' });
    const result = checkOtp(email, otp);
    if (!result.valid) return res.status(400).json({ error: result.reason });
    res.status(200).json({ message: 'OTP is valid.' });
};

// ── Reset Password — verify OTP + set new password ───────────────────────
exports.resetPassword = async (req, res) => {
    try {
        const { email, otp, newPassword } = req.body;
        if (!email || !otp || !newPassword) {
            return res.status(400).json({ error: 'Email, OTP, and new password are all required.' });
        }
        if (newPassword.length < 6) {
            return res.status(400).json({ error: 'Password must be at least 6 characters.' });
        }

        const result = await verifyOtpAndAccount(email, otp);
        if (!result.valid) {
            return res.status(400).json({ error: result.reason });
        }

        const salt = await bcrypt.genSalt(10);
        const hashed = await bcrypt.hash(newPassword, salt);
        await User.findOneAndUpdate({ email }, { password: hashed });

        res.status(200).json({ message: 'Password reset successfully. You can now log in.' });
    } catch (error) {
        console.error('[resetPassword]', error.message);
        res.status(500).json({ error: 'Failed to reset password.' });
    }
};
