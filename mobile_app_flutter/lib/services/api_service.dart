import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  // Token is loaded from disk once and kept in memory for the app session.
  // Call clearToken() on logout.
  static String? _cachedToken;

  static void clearToken() => _cachedToken = null;

  static Future<String?> _getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('jwt_token');
    return _cachedToken;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  static const _timeout = Duration(seconds: 20);

  // ── Profile ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/users/profile'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to fetch profile'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/users/profile'),
        headers: headers, body: jsonEncode(profileData),
      ).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['error'] ?? 'Failed to update profile'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  // ── Pantry ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPantry() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/pantry'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to fetch pantry'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<Map<String, dynamic>> savePantry(List<Map<String, dynamic>> items) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/pantry/update'),
        headers: headers,
        body: jsonEncode({'items': items}),
      ).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Failed to save pantry'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  // ── Recommendations ───────────────────────────────────────
  Future<Map<String, dynamic>> getRecommendations() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/recommendations'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to fetch recommendations'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  // ── Recipe Search ─────────────────────────────────────────
  Future<Map<String, dynamic>> searchRecipes({String q = '', String cuisine = '', int page = 1}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}/recipes/search').replace(queryParameters: {
        'q': q, 'cuisine': cuisine, 'page': page.toString(),
      });
      final response = await http.get(uri, headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Search failed'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  // ── Chat ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendChatMessage(String message, {String? currentRecipeId}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{'message': message};
      if (currentRecipeId != null) body['currentRecipeId'] = currentRecipeId;
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/chat'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Foodie AI failed to respond.'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  // ── Shopping List ─────────────────────────────────────────
  Future<Map<String, dynamic>> getShoppingList() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/shopping-list'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to fetch shopping list'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<Map<String, dynamic>> addToShoppingList(List<String> items) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('${ApiConstants.baseUrl}/shopping-list/add'), headers: headers, body: jsonEncode({'items': items})).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to add items'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<Map<String, dynamic>> removeFromShoppingList(List<String> items) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('${ApiConstants.baseUrl}/shopping-list/remove'), headers: headers, body: jsonEncode({'items': items})).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to remove items'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<Map<String, dynamic>> generateShoppingList(String recipeId, {List<String> ingredients = const []}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{'recipeId': recipeId};
      if (ingredients.isNotEmpty) body['ingredients'] = ingredients;
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/shopping-list/generate'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to generate list'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<Map<String, dynamic>> toggleShoppingListItem(String itemId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/shopping-list/check/$itemId'),
        headers: headers,
      ).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to toggle item'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  // ── Ratings ───────────────────────────────────────────────
  Future<Map<String, dynamic>> rateRecipe(String recipeId, int rating, {String? feedbackText}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{'recipeId': recipeId, 'rating': rating};
      if (feedbackText != null && feedbackText.isNotEmpty) body['feedbackText'] = feedbackText;
      final response = await http.post(Uri.parse('${ApiConstants.baseUrl}/ratings'), headers: headers, body: jsonEncode(body)).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to save rating'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  // ── Substitutions ─────────────────────────────────────────
  Future<Map<String, dynamic>> getSubstitutions(String recipeId, String ingredient) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('${ApiConstants.baseUrl}/substitutions'), headers: headers, body: jsonEncode({'recipeId': recipeId, 'ingredientToReplace': ingredient})).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to get substitutions'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  // ── Favourites ────────────────────────────────────────────
  Future<Map<String, dynamic>> getFavourites() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/favourites'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to fetch favourites'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<Map<String, dynamic>> addFavourite(Map<String, dynamic> recipe) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('${ApiConstants.baseUrl}/favourites'), headers: headers, body: jsonEncode(recipe)).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Failed to add favourite'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<Map<String, dynamic>> removeFavourite(String recipeId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('${ApiConstants.baseUrl}/favourites/$recipeId'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Failed to remove favourite'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }

  Future<bool> isFavourite(String recipeId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/favourites/check/$recipeId'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return jsonDecode(response.body)['isFavourite'] == true;
      return false;
    } catch (_) { return false; }
  }

  // ── Translation ───────────────────────────────────────────
  Future<Map<String, dynamic>> translateSteps(List<String> texts, {String targetLang = 'Arabic'}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/translate'),
        headers: headers,
        body: jsonEncode({'texts': texts, 'targetLang': targetLang}),
      ).timeout(const Duration(seconds: 40));
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      // Pass the actual server error message through so the UI can show it
      try {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['error'] ?? 'Translation failed (${response.statusCode})'};
      } catch (_) {
        return {'success': false, 'message': 'Translation failed (${response.statusCode})'};
      }
    } on Exception catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ── Meal Plan ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getMealPlan() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/meal-plan'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      return {'success': false, 'message': 'Failed to generate meal plan'};
    } catch (_) { return {'success': false, 'message': 'Network error'}; }
  }
}
