import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart'; // Make sure this path matches your setup!

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
  // 4. LOGOUT
  // ---------------------------------------------------------
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token'); // Delete the token to log them out
  }
}