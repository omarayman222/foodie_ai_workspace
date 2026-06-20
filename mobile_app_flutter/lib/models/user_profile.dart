class UserProfile {
  String name;
  List<String> allergies;
  List<String> diet;
  List<String> medicalConditions;
  List<String> dislikes;
  List<String> dislikedCuisines;

  UserProfile({
    this.name = '',
    List<String>? allergies,
    List<String>? diet,
    List<String>? medicalConditions,
    List<String>? dislikes,
    List<String>? dislikedCuisines,
  })  : allergies = allergies ?? [],
        diet = diet ?? [],
        medicalConditions = medicalConditions ?? [],
        dislikes = dislikes ?? [],
        dislikedCuisines = dislikedCuisines ?? [];

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      allergies: List<String>.from(json['allergies'] ?? []),
      diet: List<String>.from(json['diet'] ?? []),
      medicalConditions: List<String>.from(json['medicalConditions'] ?? []),
      dislikes: List<String>.from(json['dislikes'] ?? []),
      dislikedCuisines: List<String>.from(json['dislikedCuisines'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'allergies': allergies,
        'diet': diet,
        'medicalConditions': medicalConditions,
        'dislikes': dislikes,
        'dislikedCuisines': dislikedCuisines,
      };
}
