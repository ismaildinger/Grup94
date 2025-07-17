class WorkoutPlan {
  final String id;
  final String userId;
  final String title;
  final String description;
  final int durationWeeks;
  final int currentWeek;
  final List<WeeklyPlan> weeks;
  final DateTime createdAt;
  final DateTime lastUpdated;

  WorkoutPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.durationWeeks,
    this.currentWeek = 1,
    required this.weeks,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) : createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'durationWeeks': durationWeeks,
      'currentWeek': currentWeek,
      'weeks': weeks.map((w) => w.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      description: json['description'],
      durationWeeks: json['durationWeeks'],
      currentWeek: json['currentWeek'] ?? 1,
      weeks: (json['weeks'] as List).map((w) => WeeklyPlan.fromJson(w)).toList(),
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

class WeeklyPlan {
  final int weekNumber;
  final String focus;
  final List<DailyWorkout> dailyWorkouts;

  WeeklyPlan({
    required this.weekNumber,
    required this.focus,
    required this.dailyWorkouts,
  });

  Map<String, dynamic> toJson() {
    return {
      'weekNumber': weekNumber,
      'focus': focus,
      'dailyWorkouts': dailyWorkouts.map((d) => d.toJson()).toList(),
    };
  }

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) {
    return WeeklyPlan(
      weekNumber: json['weekNumber'],
      focus: json['focus'],
      dailyWorkouts: (json['dailyWorkouts'] as List)
          .map((d) => DailyWorkout.fromJson(d))
          .toList(),
    );
  }
}

class DailyWorkout {
  final int dayNumber;
  final String dayName;
  final String type; // 'workout', 'rest', 'cardio'
  final String? title;
  final String? description;
  final List<Exercise> exercises;
  final bool isCompleted;
  final DateTime? completedAt;

  DailyWorkout({
    required this.dayNumber,
    required this.dayName,
    required this.type,
    this.title,
    this.description,
    required this.exercises,
    this.isCompleted = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'dayNumber': dayNumber,
      'dayName': dayName,
      'type': type,
      'title': title,
      'description': description,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory DailyWorkout.fromJson(Map<String, dynamic> json) {
    return DailyWorkout(
      dayNumber: json['dayNumber'],
      dayName: json['dayName'],
      type: json['type'],
      title: json['title'],
      description: json['description'],
      exercises: (json['exercises'] as List? ?? [])
          .map((e) => Exercise.fromJson(e))
          .toList(),
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }

  DailyWorkout copyWith({
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return DailyWorkout(
      dayNumber: dayNumber,
      dayName: dayName,
      type: type,
      title: title,
      description: description,
      exercises: exercises,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class Exercise {
  final String name;
  final String description;
  final int? sets;
  final int? reps;
  final int? duration; // saniye cinsinden
  final String? notes;

  Exercise({
    required this.name,
    required this.description,
    this.sets,
    this.reps,
    this.duration,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'sets': sets,
      'reps': reps,
      'duration': duration,
      'notes': notes,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'],
      description: json['description'],
      sets: json['sets'],
      reps: json['reps'],
      duration: json['duration'],
      notes: json['notes'],
    );
  }
}
