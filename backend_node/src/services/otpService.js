/**
 * OTP Service — EmailJS edition
 * Everything OTP-related lives here: generate, store, send, verify, cleanup.
 */

const axios = require('axios');
const User  = require('../models/User');

// ── EmailJS credentials ───────────────────────────────────────────────────
const EMAILJS_URL        = 'https://api.emailjs.com/api/v1.0/email/send';
const EMAILJS_SERVICE_ID  = 'service_s9j129w';
const EMAILJS_TEMPLATE_ID = 'template_zo4c0zr';
const EMAILJS_PUBLIC_KEY  = 'TedA_I4JzKN6YJq6y';
const EMAILJS_PRIVATE_KEY = 'PC-V6tzgICrMRWLYoHZt1';

// ── OTP config ────────────────────────────────────────────────────────────
const OTP_LENGTH         = 6;
const OTP_EXPIRY_MINUTES = 10;

// ── In-memory stores (email → otp / expiry timestamp) ────────────────────
const otpStore  = new Map();
const otpExpiry = new Map();

// ── Helpers ───────────────────────────────────────────────────────────────
function _generate() {
    return String(Math.floor(Math.random() * Math.pow(10, OTP_LENGTH))).padStart(OTP_LENGTH, '0');
}

function _store(email, otp) {
    const expiresAt = Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000;
    otpStore.set(email, otp);
    otpExpiry.set(email, expiresAt);

    // Auto-cleanup after expiry
    setTimeout(() => {
        otpStore.delete(email);
        otpExpiry.delete(email);
    }, OTP_EXPIRY_MINUTES * 60 * 1000);
}

function _formatExpiry() {
    const d = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);
    return d.toISOString().replace('T', ' ').slice(0, 19);
}

// ── Send via EmailJS ──────────────────────────────────────────────────────
async function _sendEmail(toEmail, userName, otp) {
    const payload = {
        service_id:  EMAILJS_SERVICE_ID,
        template_id: EMAILJS_TEMPLATE_ID,
        user_id:     EMAILJS_PUBLIC_KEY,
        accessToken: EMAILJS_PRIVATE_KEY,
        template_params: {
            email:     toEmail,
            user_name: userName || toEmail.split('@')[0],
            passcode:  otp,
            time:      _formatExpiry(),
        },
    };

    const response = await axios.post(EMAILJS_URL, payload, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 30000,
        validateStatus: () => true, // don't throw on 4xx/5xx so we can log the body
    });

    console.log(`[EmailJS] status=${response.status} body=${JSON.stringify(response.data)}`);

    if (response.status < 200 || response.status >= 300) {
        throw new Error(`EmailJS ${response.status}: ${JSON.stringify(response.data)}`);
    }
}

// ── Public API ────────────────────────────────────────────────────────────

/**
 * Generate an OTP for `email`, store it, and send it via EmailJS.
 * @param {string} email     - recipient email (used as the store key)
 * @param {string} userName  - displayed in the email template
 */
async function generateAndSendOtp(email, userName) {
    const otp = _generate();
    _store(email, otp);
    console.log(`[OTP] Generated for ${email}: ${otp} (expires in ${OTP_EXPIRY_MINUTES} min)`);
    await _sendEmail(email, userName, otp);
}

/**
 * Verify the OTP a user typed in.
 * Returns { valid: true } or { valid: false, reason: '...' }
 * Clears the OTP on success.
 */
function verifyOtp(email, otp) {
    const stored = otpStore.get(email);
    if (!stored) {
        return { valid: false, reason: 'No OTP was requested for this email.' };
    }

    const expiry = otpExpiry.get(email);
    if (!expiry || Date.now() > expiry) {
        otpStore.delete(email);
        otpExpiry.delete(email);
        return { valid: false, reason: 'OTP has expired. Please request a new one.' };
    }

    if (stored !== String(otp).trim()) {
        return { valid: false, reason: 'Incorrect OTP. Please try again.' };
    }

    // Success — consume the OTP so it can't be reused
    otpStore.delete(email);
    otpExpiry.delete(email);
    return { valid: true };
}

/**
 * Check OTP correctness without consuming it — used at step 2 so the user
 * can be blocked before reaching the new-password form.
 * The OTP is NOT deleted; verifyOtpAndAccount() does that at the final step.
 */
function checkOtp(email, otp) {
    const stored = otpStore.get(email);
    if (!stored) return { valid: false, reason: 'No OTP was requested for this email.' };

    const expiry = otpExpiry.get(email);
    if (!expiry || Date.now() > expiry) {
        otpStore.delete(email);
        otpExpiry.delete(email);
        return { valid: false, reason: 'OTP has expired. Please request a new one.' };
    }

    if (stored !== String(otp).trim()) {
        return { valid: false, reason: 'Incorrect OTP. Please try again.' };
    }

    return { valid: true }; // intentionally NOT deleting — step 3 will do that
}

/**
 * Verify both that the email has a registered account AND that the OTP is correct.
 * Used by the reset-password endpoint so all validation lives in one place.
 * Returns { valid: true } or { valid: false, reason: '...' }
 * Clears the OTP on success.
 */
async function verifyOtpAndAccount(email, otp) {
    const user = await User.findOne({ email });
    if (!user) {
        return { valid: false, reason: 'No account found with this email.' };
    }

    const stored = otpStore.get(email);
    if (!stored) {
        return { valid: false, reason: 'No OTP was requested for this email.' };
    }

    const expiry = otpExpiry.get(email);
    if (!expiry || Date.now() > expiry) {
        otpStore.delete(email);
        otpExpiry.delete(email);
        return { valid: false, reason: 'OTP has expired. Please request a new one.' };
    }

    if (stored !== String(otp).trim()) {
        return { valid: false, reason: 'Incorrect OTP. Please try again.' };
    }

    otpStore.delete(email);
    otpExpiry.delete(email);
    return { valid: true };
}

module.exports = { generateAndSendOtp, verifyOtp, checkOtp, verifyOtpAndAccount };
