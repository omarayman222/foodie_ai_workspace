class UserProfile {
  List<String> allergies;
  List<String> diet;
  List<String> medicalConditions;
  List<String> dislikes;
  List<String> dislikedCuisines;

  UserProfile({
    this.allergies = const [],
    this.diet = const [],
    this.medicalConditions = const [],
    this.dislikes = const [],
    this.dislikedCuisines = const [],
  });

  // Translator: JSON (from Node.js) -> Dart
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      allergies: List<String>.from(json['allergies'] ?? []),
      diet: List<String>.from(json['diet'] ?? []),
      medicalConditions: List<String>.from(json['medicalConditions'] ?? []),
      dislikes: List<String>.from(json['dislikes'] ?? []),
      dislikedCuisines: List<String>.from(json['dislikedCuisines'] ?? []),
    );
  }

  // Translator: Dart -> JSON (To send to Node.js)
  Map<String, dynamic> toJson() {
    return {
      'allergies': allergies,
      'diet': diet,
      'medicalConditions': medicalConditions,
      'dislikes': dislikes,
      'dislikedCuisines': dislikedCuisines,
    };
  }
}