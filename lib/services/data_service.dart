import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/workout_plan.dart';
import '../models/progress_entry.dart';

class DataService {
  static late SharedPreferences _prefs;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // User Profile Methods
  static Future<void> saveUserProfile(UserProfile profile) async {
    await initialize();
    await _prefs.setString('user_profile', jsonEncode(profile.toJson()));
  }

  static Future<UserProfile?> getUserProfile() async {
    await initialize();
    final jsonString = _prefs.getString('user_profile');
    if (jsonString == null) return null;
    return UserProfile.fromJson(jsonDecode(jsonString));
  }

  static Future<void> deleteUserProfile() async {
    await initialize();
    await _prefs.remove('user_profile');
  }

  // Workout Plan Methods
  static Future<void> saveWorkoutPlan(WorkoutPlan plan) async {
    await initialize();
    await _prefs.setString('workout_plan', jsonEncode(plan.toJson()));
  }

  static Future<WorkoutPlan?> getWorkoutPlan() async {
    await initialize();
    final jsonString = _prefs.getString('workout_plan');
    if (jsonString == null) return null;
    return WorkoutPlan.fromJson(jsonDecode(jsonString));
  }

  static Future<void> deleteWorkoutPlan() async {
    await initialize();
    await _prefs.remove('workout_plan');
  }

  // Progress Entries Methods
  static Future<void> saveProgressEntry(ProgressEntry entry) async {
    await initialize();
    final entries = await getProgressEntries();
    
    // Remove existing entry for the same date if exists
    entries.removeWhere((e) => 
        e.date.year == entry.date.year &&
        e.date.month == entry.date.month &&
        e.date.day == entry.date.day);
    
    entries.add(entry);
    
    // Sort by date
    entries.sort((a, b) => a.date.compareTo(b.date));
    
    final jsonList = entries.map((e) => e.toJson()).toList();
    await _prefs.setString('progress_entries', jsonEncode(jsonList));
  }

  static Future<List<ProgressEntry>> getProgressEntries() async {
    await initialize();
    final jsonString = _prefs.getString('progress_entries');
    if (jsonString == null) return [];
    
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => ProgressEntry.fromJson(json)).toList();
  }

  static Future<ProgressEntry?> getTodayProgress() async {
    await initialize();
    final entries = await getProgressEntries();
    final today = DateTime.now();
    
    return entries.where((entry) =>
        entry.date.year == today.year &&
        entry.date.month == today.month &&
        entry.date.day == today.day).firstOrNull;
  }

  static Future<void> deleteProgressEntry(String entryId) async {
    await initialize();
    final entries = await getProgressEntries();
    entries.removeWhere((e) => e.id == entryId);
    
    final jsonList = entries.map((e) => e.toJson()).toList();
    await _prefs.setString('progress_entries', jsonEncode(jsonList));
  }

  // Total Points Methods
  static Future<int> getTotalPoints() async {
    await initialize();
    final entries = await getProgressEntries();
    int total = 0;
    for (var entry in entries) {
      total += entry.totalPoints;
    }
    return total;
  }

  // Streak Methods
  static Future<int> getCurrentStreak() async {
    await initialize();
    final entries = await getProgressEntries();
    if (entries.isEmpty) return 0;

    // Sort by date descending
    entries.sort((a, b) => b.date.compareTo(a.date));
    
    int streak = 0;
    DateTime currentDate = DateTime.now();
    
    for (var entry in entries) {
      // Check if this entry is for yesterday or today
      final daysDifference = currentDate.difference(entry.date).inDays;
      
      if (daysDifference == streak && entry.workoutCompleted) {
        streak++;
        currentDate = entry.date;
      } else {
        break;
      }
    }
    
    return streak;
  }

  // Clear all data
  static Future<void> clearAllData() async {
    await initialize();
    await _prefs.clear();
  }

  // Check if user setup is complete
  static Future<bool> isUserSetupComplete() async {
    final profile = await getUserProfile();
    return profile != null;
  }

  // Get user's current week number
  static Future<int> getCurrentWeekNumber() async {
    final plan = await getWorkoutPlan();
    return plan?.currentWeek ?? 1;
  }

  // Update current week
  static Future<void> updateCurrentWeek(int weekNumber) async {
    final plan = await getWorkoutPlan();
    if (plan != null) {
      final updatedPlan = WorkoutPlan(
        id: plan.id,
        userId: plan.userId,
        title: plan.title,
        description: plan.description,
        durationWeeks: plan.durationWeeks,
        currentWeek: weekNumber,
        weeks: plan.weeks,
        createdAt: plan.createdAt,
        lastUpdated: DateTime.now(),
      );
      await saveWorkoutPlan(updatedPlan);
    }
  }
}
