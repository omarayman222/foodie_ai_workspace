class Recipe {
  final String id;
  final String title;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> instructions;
  final String prepTime;
  final String cookTime;
  final String totalTime;
  final String servings;
  final String nutrition;
  final String cuisine;
  final double rating;

  Recipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.instructions,
    required this.prepTime,
    this.cookTime = '',
    this.totalTime = '',
    this.servings = '',
    this.nutrition = '',
    this.cuisine = '',
    this.rating = 0.0,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final raw = json['directions'] ?? json['instructions'];
    List<String> steps = [];
    if (raw is List) {
      steps = List<String>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      steps = raw
          .split(RegExp(r'\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return Recipe(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['recipe_name'] ?? json['title'] ?? 'Unknown Recipe',
      imageUrl: json['img_src'] ?? json['imageUrl'] ?? '',
      ingredients: json['ingredients'] != null ? List<String>.from(json['ingredients']) : [],
      instructions: steps,
      prepTime: json['prep_time'] ?? json['prepTime']?.toString() ?? '',
      cookTime: json['cook_time'] ?? '',
      totalTime: json['total_time'] ?? '',
      servings: json['servings']?.toString() ?? '',
      nutrition: json['nutrition'] ?? '',
      cuisine: json['cuisine_path'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
    );
  }
}
