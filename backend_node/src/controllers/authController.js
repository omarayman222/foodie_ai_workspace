const User = require('../models/User');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

exports.register = async (req, res) => {
    try {
        const { email, password } = req.body;

        // 1. Hash the password for security
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // 2. Create the new user
        const newUser = new User({
            email: email,
            password: hashedPassword,
            profile: { allergies: [], diet: [] }
        });

        // 3. SAVE to MongoDB
        await newUser.save(); 
        
        res.status(201).json({ message: "User registered successfully!", userId: newUser._id });
    } catch (error) {
        res.status(500).json({ error: "Failed to register user", details: error.message });
    }
};

exports.login = async (req, res) => {
    try {
        const { email, password } = req.body;

        // 1. Check if the user exists
        const user = await User.findOne({ email });
        if (!user) {
            return res.status(400).json({ error: "Invalid email or password" });
        }

        // 2. Check if the password matches
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ error: "Invalid email or password" });
        }

        // 3. Generate the JWT "VIP Wristband"
        const token = jwt.sign(
            { userId: user._id }, 
            process.env.JWT_SECRET, 
            { expiresIn: '7d' } 
        );

        res.status(200).json({ 
            message: "Login successful!", 
            token: token,
            userId: user._id
        });
    } catch (error) {
        // Here is the catch block that fixes the syntax error!
        res.status(500).json({ error: "Failed to log in", details: error.message });
    }
};