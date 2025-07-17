class UserProfile {
  final String id;
  final String name;
  final int age;
  final double height; // cm
  final double currentWeight; // kg
  final double targetWeight; // kg
  final String gender;
  final String activityLevel;
  final List<String> healthConditions;
  final List<String> goals;
  final DateTime createdAt;
  final DateTime lastUpdated;

  UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    required this.gender,
    required this.activityLevel,
    required this.healthConditions,
    required this.goals,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) : createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'height': height,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'gender': gender,
      'activityLevel': activityLevel,
      'healthConditions': healthConditions,
      'goals': goals,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      age: json['age'],
      height: json['height'],
      currentWeight: json['currentWeight'],
      targetWeight: json['targetWeight'],
      gender: json['gender'],
      activityLevel: json['activityLevel'],
      healthConditions: List<String>.from(json['healthConditions']),
      goals: List<String>.from(json['goals']),
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  UserProfile copyWith({
    String? name,
    int? age,
    double? height,
    double? currentWeight,
    double? targetWeight,
    String? gender,
    String? activityLevel,
    List<String>? healthConditions,
    List<String>? goals,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      height: height ?? this.height,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      healthConditions: healthConditions ?? this.healthConditions,
      goals: goals ?? this.goals,
      createdAt: createdAt,
      lastUpdated: DateTime.now(),
    );
  }
}
