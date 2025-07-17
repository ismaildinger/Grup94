import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class DailyTask {
  final String id;
  final String name;
  final String description;
  final int points;
  final String category; // 'exercise', 'nutrition', 'hydration', 'sleep'
  final DateTime date;
  bool completed;

  DailyTask({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    required this.category,
    required this.date,
    this.completed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'points': points,
      'category': category,
      'date': date.toIso8601String(),
      'completed': completed,
    };
  }

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      points: json['points'],
      category: json['category'],
      date: DateTime.parse(json['date']),
      completed: json['completed'] ?? false,
    );
  }
}

class TaskService {
  static Future<List<DailyTask>> generateDailyTasks(UserProfile profile) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month}-${today.day}';
    
    // Bugünün taskları zaten oluşturulmuş mu kontrol et
    final prefs = await SharedPreferences.getInstance();
    final existingTasks = prefs.getString('tasks_$dateKey');
    
    if (existingTasks != null) {
      final List<dynamic> taskList = jsonDecode(existingTasks);
      return taskList.map((task) => DailyTask.fromJson(task)).toList();
    }

    // Yeni tasklar oluştur
    List<DailyTask> tasks = [];
    
    // Kullanıcı seviyesine göre task zorlukları
    final isBeginnerLevel = profile.activityLevel == 'sedanter' || profile.activityLevel == 'az aktif';
    final isWeightLoss = profile.targetWeight < profile.currentWeight;
    
    // Egzersiz Taskları
    if (isBeginnerLevel) {
      tasks.addAll([
        DailyTask(
          id: 'exercise_1_$dateKey',
          name: '10 Dakika Yürüyüş',
          description: 'Rahat tempoda 10 dakika yürüyüş yap',
          points: 20,
          category: 'exercise',
          date: today,
        ),
        DailyTask(
          id: 'exercise_2_$dateKey', 
          name: '5 Şınav',
          description: 'Dizler üzerinde de yapabilirsin',
          points: 15,
          category: 'exercise',
          date: today,
        ),
      ]);
    } else {
      tasks.addAll([
        DailyTask(
          id: 'exercise_1_$dateKey',
          name: '15 Şınav',
          description: 'Standart şınav, 3 sette bölebilirsin',
          points: 25,
          category: 'exercise',
          date: today,
        ),
        DailyTask(
          id: 'exercise_2_$dateKey',
          name: '20 Squat',
          description: 'Doğru formda çömelme hareketi',
          points: 25,
          category: 'exercise',
          date: today,
        ),
        DailyTask(
          id: 'exercise_3_$dateKey',
          name: '1 Dakika Plank',
          description: 'Karın kasları için static tutma',
          points: 20,
          category: 'exercise',
          date: today,
        ),
      ]);
    }

    // Beslenme Taskları
    if (isWeightLoss) {
      tasks.addAll([
        DailyTask(
          id: 'nutrition_1_$dateKey',
          name: 'Protein Ağırlıklı Kahvaltı',
          description: 'Yumurta, yoğurt veya peynir içeren kahvaltı',
          points: 15,
          category: 'nutrition',
          date: today,
        ),
        DailyTask(
          id: 'nutrition_2_$dateKey',
          name: 'Sebze Porsiyonu',
          description: 'Öğle ve akşam yemeğinde bol sebze tüket',
          points: 15,
          category: 'nutrition',
          date: today,
        ),
      ]);
    } else {
      tasks.addAll([
        DailyTask(
          id: 'nutrition_1_$dateKey',
          name: 'Kaliteli Karbonhidrat',
          description: 'Tam tahıl, bulgur veya yulaf tüket',
          points: 15,
          category: 'nutrition',
          date: today,
        ),
        DailyTask(
          id: 'nutrition_2_$dateKey',
          name: 'Protein Kaynağı',
          description: 'Et, balık, yumurta veya baklagil tüket',
          points: 15,
          category: 'nutrition',
          date: today,
        ),
      ]);
    }

    // Genel Sağlık Taskları
    tasks.addAll([
      DailyTask(
        id: 'hydration_$dateKey',
        name: '2 Litre Su',
        description: 'Gün boyunca en az 2 litre su iç',
        points: 10,
        category: 'hydration',
        date: today,
      ),
      DailyTask(
        id: 'sleep_$dateKey',
        name: '7+ Saat Uyku',
        description: 'Kaliteli ve yeterli uyku al',
        points: 15,
        category: 'sleep',
        date: today,
      ),
    ]);

    // Taskları kaydet
    await _saveTasks(dateKey, tasks);
    return tasks;
  }

  static Future<void> _saveTasks(String dateKey, List<DailyTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString('tasks_$dateKey', tasksJson);
  }

  static Future<List<DailyTask>> getTodaysTasks() async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month}-${today.day}';
    
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString('tasks_$dateKey');
    
    if (tasksJson == null) return [];
    
    final List<dynamic> taskList = jsonDecode(tasksJson);
    return taskList.map((task) => DailyTask.fromJson(task)).toList();
  }

  static Future<void> completeTask(String taskId) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month}-${today.day}';
    
    final tasks = await getTodaysTasks();
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);
    
    if (taskIndex != -1) {
      tasks[taskIndex].completed = true;
      await _saveTasks(dateKey, tasks);
      
      // Tamamlanan task puanını ekle
      await _addPoints(tasks[taskIndex].points);
    }
  }

  static Future<void> _addPoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPoints = prefs.getInt('total_points') ?? 0;
    await prefs.setInt('total_points', currentPoints + points);
  }

  static Future<int> getTodayCompletedTasksCount() async {
    final tasks = await getTodaysTasks();
    return tasks.where((task) => task.completed).length;
  }

  static Future<int> getTodayTotalTasksCount() async {
    final tasks = await getTodaysTasks();
    return tasks.length;
  }

  static Future<String> getTasksSummary() async {
    final tasks = await getTodaysTasks();
    final completed = tasks.where((task) => task.completed).length;
    final total = tasks.length;
    
    if (tasks.isEmpty) return 'Bugün için henüz task oluşturulmamış.';
    
    String summary = '📋 **Bugünün Görevleri ($completed/$total)**\n\n';
    
    // Kategoriye göre grupla
    final exerciseTasks = tasks.where((task) => task.category == 'exercise').toList();
    final nutritionTasks = tasks.where((task) => task.category == 'nutrition').toList();
    final otherTasks = tasks.where((task) => !['exercise', 'nutrition'].contains(task.category)).toList();
    
    if (exerciseTasks.isNotEmpty) {
      summary += '💪 **Egzersiz Görevleri:**\n';
      for (var task in exerciseTasks) {
        final status = task.completed ? '✅' : '⭕';
        summary += '$status ${task.name} (${task.points} puan)\n';
        summary += '   ${task.description}\n\n';
      }
    }
    
    if (nutritionTasks.isNotEmpty) {
      summary += '🥗 **Beslenme Görevleri:**\n';
      for (var task in nutritionTasks) {
        final status = task.completed ? '✅' : '⭕';
        summary += '$status ${task.name} (${task.points} puan)\n';
        summary += '   ${task.description}\n\n';
      }
    }
    
    if (otherTasks.isNotEmpty) {
      summary += '🌟 **Diğer Görevler:**\n';
      for (var task in otherTasks) {
        final status = task.completed ? '✅' : '⭕';
        summary += '$status ${task.name} (${task.points} puan)\n';
        summary += '   ${task.description}\n\n';
      }
    }
    
    final totalPoints = tasks.fold(0, (sum, task) => sum + (task.completed ? task.points : 0));
    summary += '🏆 **Bugün Kazanılan Puan:** $totalPoints\n';
    
    if (completed == total) {
      summary += '\n🎉 Tebrikler! Bugünün tüm görevlerini tamamladın!';
    } else {
      summary += '\n💪 ${total - completed} görev daha var, devam et!';
    }
    
    return summary;
  }
}
