import 'recipe.dart';

class ChatMessage {
  final String text;
  final bool isUser; // True if the user sent it, False if the AI sent it
  final String? type; // 'SEARCH', 'COOKING', 'GENERAL'
  final List<Recipe> recipes; // Only populated if it was a search request

  ChatMessage({
    required this.text,
    required this.isUser,
    this.type,
    this.recipes = const [],
  });

  factory ChatMessage.fromAiResponse(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['reply'] ?? 'Sorry, I encountered an error.',
      isUser: false,
      type: json['type'],
      
      // If the AI sent recipes, translate them all into Dart objects
      recipes: json['recipes'] != null 
          ? (json['recipes'] as List).map((i) => Recipe.fromJson(i)).toList()
          : [],
    );
  }
}