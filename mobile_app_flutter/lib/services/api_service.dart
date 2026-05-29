import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart'; // Ensure this points to your ApiConstants file

class ApiService {
  
  // ==========================================
  // THE TOKEN INJECTOR
  // ==========================================
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    return {
      'Content-Type': 'application/json',
      // If the token exists, attach it as a Bearer token. Otherwise, send empty.
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  // ==========================================
  // 1. UPDATE PROFILE (Allergies, Medical, Diets)
  // ==========================================
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/user/profile'), // Matches Node.js route
        headers: headers,
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'message': errorData['error'] ?? 'Failed to update profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error. Check server connection.'};
    }
  }

  // ==========================================
  // 2. GET DASHBOARD RECOMMENDATIONS (Cold Start)
  // ==========================================
  Future<Map<String, dynamic>> getRecommendations() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/recommendations'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Failed to fetch recommendations'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error. Check server connection.'};
    }
  }

  // ==========================================
  // 3. SEND CHAT MESSAGE (The Master Agent Router)
  // ==========================================
  Future<Map<String, dynamic>> sendChatMessage(String message, {String? currentRecipeId}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/chat'),
        headers: headers,
        body: jsonEncode({
          'message': message,
          // Only attach currentRecipeId if they are looking at a specific recipe
          if (currentRecipeId != null) 'currentRecipeId': currentRecipeId,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Foodie AI failed to respond.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error. Check server connection.'};
    }
  }
}