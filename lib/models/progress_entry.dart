class ProgressEntry {
  final String id;
  final String userId;
  final DateTime date;
  final double? weight;
  final String? mood; // 'excellent', 'good', 'okay', 'bad', 'terrible'
  final int? energyLevel; // 1-10
  final int? stressLevel; // 1-10
  final String? notes;
  final bool workoutCompleted;
  final List<String> completedExercises;
  final int totalPoints;

  ProgressEntry({
    required this.id,
    required this.userId,
    required this.date,
    this.weight,
    this.mood,
    this.energyLevel,
    this.stressLevel,
    this.notes,
    this.workoutCompleted = false,
    this.completedExercises = const [],
    this.totalPoints = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'weight': weight,
      'mood': mood,
      'energyLevel': energyLevel,
      'stressLevel': stressLevel,
      'notes': notes,
      'workoutCompleted': workoutCompleted,
      'completedExercises': completedExercises,
      'totalPoints': totalPoints,
    };
  }

  factory ProgressEntry.fromJson(Map<String, dynamic> json) {
    return ProgressEntry(
      id: json['id'],
      userId: json['userId'],
      date: DateTime.parse(json['date']),
      weight: json['weight']?.toDouble(),
      mood: json['mood'],
      energyLevel: json['energyLevel'],
      stressLevel: json['stressLevel'],
      notes: json['notes'],
      workoutCompleted: json['workoutCompleted'] ?? false,
      completedExercises: List<String>.from(json['completedExercises'] ?? []),
      totalPoints: json['totalPoints'] ?? 0,
    );
  }

  ProgressEntry copyWith({
    double? weight,
    String? mood,
    int? energyLevel,
    int? stressLevel,
    String? notes,
    bool? workoutCompleted,
    List<String>? completedExercises,
    int? totalPoints,
  }) {
    return ProgressEntry(
      id: id,
      userId: userId,
      date: date,
      weight: weight ?? this.weight,
      mood: mood ?? this.mood,
      energyLevel: energyLevel ?? this.energyLevel,
      stressLevel: stressLevel ?? this.stressLevel,
      notes: notes ?? this.notes,
      workoutCompleted: workoutCompleted ?? this.workoutCompleted,
      completedExercises: completedExercises ?? this.completedExercises,
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }
}
