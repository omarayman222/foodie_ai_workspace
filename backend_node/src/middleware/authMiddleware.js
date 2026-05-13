const jwt = require('jsonwebtoken');

module.exports = (req, res, next) => {
    // Look for the token in the headers
    const token = req.header('Authorization');
    
    if (!token) return res.status(401).json({ error: "Access Denied. No token provided." });

    try {
        // Verify the token
        const verified = jwt.verify(token.replace("Bearer ", ""), process.env.JWT_SECRET);
        req.user = verified; // Attach the user ID to the request
        next(); // Let them through!
    } catch (err) {
        res.status(400).json({ error: "Invalid Token" });
    }
};