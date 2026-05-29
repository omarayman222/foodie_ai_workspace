class Recipe {
  final String id;
  final String title;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> instructions;
  final int prepTime;

  Recipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.instructions,
    required this.prepTime,
  });

  // This factory method is the translator: JSON to Dart
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Unknown Recipe',
      imageUrl: json['imageUrl'] ?? json['image'] ?? 'https://via.placeholder.com/150', // Fallback image so the app never crashes
      
      // We map through lists safely to prevent crashes if the database sends null
      ingredients: json['ingredients'] != null ? List<String>.from(json['ingredients']) : [],
      instructions: json['instructions'] != null ? List<String>.from(json['instructions']) : [],
      
      prepTime: json['prepTime'] ?? 0,
    );
  }
}