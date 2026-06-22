import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'api_service.dart';

class AuthService {

  // ---------------------------------------------------------
  // 1. REGISTER A NEW USER
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.registerEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Registration successful!'};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'message': errorData['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server error. Please ensure Node.js is running.'};
    }
  }

  // ---------------------------------------------------------
  // 2. LOGIN & SAVE TOKEN
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 🚨 THE CRUCIAL STEP: Save the JWT Token to the phone's secure storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        if (data['userId'] != null) await prefs.setString('user_id', data['userId']);
        ApiService.clearToken(); // force re-read of the new token on next API call

        return {'success': true, 'message': 'Login successful!'};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'message': errorData['error'] ?? 'Invalid credentials'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server error. Please ensure Node.js is running.'};
    }
  }

  // ---------------------------------------------------------
  // 3. GET SAVED TOKEN (For future API calls)
  // ---------------------------------------------------------
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // ---------------------------------------------------------
  // EMAIL SENDER CONFIG (stored in DB)
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> getEmailConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/settings/email-config'),
      ).timeout(const Duration(seconds: 10));
      Map<String, dynamic> data = {};
      try { data = jsonDecode(response.body); } catch (_) {}
      if (response.statusCode == 200) return {'success': true, 'data': data};
      return {'success': false, 'message': data['error'] ?? 'Failed to load config'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot reach server.'};
    }
  }

  Future<Map<String, dynamic>> saveEmailConfig(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/settings/email-config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emailUser': email, 'emailPass': password}),
      ).timeout(const Duration(seconds: 10));
      Map<String, dynamic> data = {};
      try { data = jsonDecode(response.body); } catch (_) {}
      if (response.statusCode == 200) return {'success': true, 'message': data['message']};
      return {'success': false, 'message': data['error'] ?? 'Failed to save config'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot reach server.'};
    }
  }

  // ---------------------------------------------------------
  // 3b. REQUEST OTP FOR PASSWORD RESET
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> requestOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try { data = jsonDecode(response.body); } catch (_) {}

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'OTP sent'};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to send OTP (status ${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot reach server. Please restart Node.js and try again.'};
    }
  }

  // ---------------------------------------------------------
  // 3b2. CHECK OTP (validate without consuming — step 2 gate)
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> checkOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/check-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try { data = jsonDecode(response.body); } catch (_) {}

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'OTP valid'};
      }
      return {'success': false, 'message': data['error'] ?? 'Invalid OTP'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot reach server.'};
    }
  }

  // ---------------------------------------------------------
  // 3c. RESET PASSWORD WITH OTP
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp, 'newPassword': newPassword}),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try { data = jsonDecode(response.body); } catch (_) {}

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Password reset'};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to reset password (status ${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot reach server. Please restart Node.js and try again.'};
    }
  }

  // ---------------------------------------------------------
  // 4. LOGOUT
  // ---------------------------------------------------------
  Future<void> logout() async {
    ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
}