import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../models/workout_plan.dart';
import '../models/progress_entry.dart';
import 'data_service.dart';
import 'task_service.dart';

class HealthAIService {
  static late GenerativeModel _model;
  static bool _initialized = false;
  static const Uuid _uuid = Uuid();

  // Retry mekanizması ile API çağrısı
  static Future<GenerateContentResponse> _generateContentWithRetry(
    List<Content> content, 
    {int maxRetries = 3, int delaySeconds = 2}
  ) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await _model.generateContent(content);
      } catch (e) {
        if (i == maxRetries - 1) {
          // Son deneme de başarısız
          throw e;
        }
        
        // 503 hatası veya server overload durumunda bekle
        if (e.toString().contains('503') || 
            e.toString().contains('overloaded') || 
            e.toString().contains('UNAVAILABLE')) {
          await Future.delayed(Duration(seconds: delaySeconds * (i + 1)));
          continue;
        } else {
          // Başka bir hata türü, hemen fırlat
          throw e;
        }
      }
    }
    
    throw Exception('Max retry attempts exceeded');
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await dotenv.load(fileName: ".env");
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not found in .env file');
      }

      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.6,
          topK: 32,
          topP: 0.9,
          maxOutputTokens: 1024,
        ),
      );
      
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Health AI: $e');
    }
  }

  static Future<String> getWelcomeMessage() async {
    if (!_initialized) await initialize();
    
    final profile = await DataService.getUserProfile();
    
    if (profile == null) {
      return """
Merhaba! Ben sizin kişisel sağlık AI asistanınızım! 🏃‍♂️💪

Size özel bir sağlık ve fitness planı hazırlamak için birkaç soru sormam gerekiyor. Bu bilgiler tamamen güvenli bir şekilde saklanacak.

Başlamaya hazır mısınız? İlk olarak adınızı öğrenebilir miyim?
""";
    } else {
      final totalPoints = await DataService.getTotalPoints();
      final streak = await DataService.getCurrentStreak();
      
      return """
Tekrar hoş geldin ${profile.name}! 🎉

📊 Toplam Puanın: $totalPoints
🔥 Mevcut Sertin: $streak gün

Bugün nasıl hissediyorsun? Antrenmanını tamamladın mı?
""";
    }
  }

  static Future<String> processUserInput(String input, List<Map<String, String>> chatHistory) async {
    if (!_initialized) await initialize();

    try {
      final profile = await DataService.getUserProfile();
      
      if (profile == null) {
        return await _handleProfileSetup(input, chatHistory);
      } else {
        return await _handleExistingUser(input, chatHistory, profile);
      }
    } catch (e) {
      return 'Üzgünüm, bir hata oluştu: $e';
    }
  }

  static Future<String> _handleProfileSetup(String input, List<Map<String, String>> chatHistory) async {
    // Kullanıcı profilini oluşturmak için gerekli bilgileri topla
    String prompt = """
Sen bir uzman sağlık ve fitness AI asistanısın. Kullanıcıdan profil bilgilerini toplamaya çalışıyorsun.

Şu bilgileri sırayla öğrenmelisin:
1. Ad
2. Yaş  
3. Cinsiyet (erkek/kadın)
4. Boy (cm cinsinden)
5. Mevcut kilo (kg cinsinden)
6. Hedef kilo (kg cinsinden) 
7. Aktivite seviyesi (sedanter/az aktif/orta/aktif/çok aktif)
8. Sağlık durumu/hastalıklar (varsa)
9. Fitness hedefleri (kilo verme/alma, kas geliştirme, dayanıklılık, calisthenics vb.)

Geçmiş konuşma:
${chatHistory.map((msg) => '${msg['role']}: ${msg['content']}').join('\n')}

Kullanıcının son mesajı: $input

KURALLAR:
- Sıcak, samimi ve motive edici ol
- Her seferinde sadece 1-2 soru sor, overwhelm etme
- Türkçe cevap ver
- Önceki cevapları dikkate al ve referans ver
- Sayısal değerler istediğinde açık ol (örn: "Boyunuzu cm cinsinden söyleyebilir misiniz?")
- Eğer tüm kritik bilgiler toplandıysa "PROFILE_COMPLETE:" ile başlayan bir mesaj gönder ve ardından kullanıcı bilgilerini özet olarak JSON formatında ver

Minimum gereken bilgiler: ad, yaş, cinsiyet, boy, mevcut kilo, hedef kilo, aktivite seviyesi, hedefler

Cevap:
""";

    final content = [Content.text(prompt)];
    final response = await _generateContentWithRetry(content);
    
    String aiResponse = response.text ?? 'Üzgünüm, yanıt oluşturamadım.';
    
    // Profil tamamlandı mı kontrol et
    if (aiResponse.startsWith('PROFILE_COMPLETE:')) {
      await _createUserProfileFromChat(chatHistory, input);
      aiResponse = await _generateDailyTasks();
    }
    
    return aiResponse;
  }

  static Future<void> _createUserProfileFromChat(List<Map<String, String>> chatHistory, String lastInput) async {
    // Chat geçmişinden bilgileri çıkaran akıllı sistem
    String extractPrompt = """
Aşağıdaki konuşmadan kullanıcının profil bilgilerini çıkar ve JSON formatında ver:

Konuşma:
${chatHistory.map((msg) => '${msg['role']}: ${msg['content']}').join('\n')}
Son mesaj: $lastInput

Çıkarılacak bilgiler:
- name (string): Kullanıcının adı
- age (number): Yaş
- gender (string): "erkek" veya "kadın"  
- height (number): Boy cm cinsinden
- currentWeight (number): Mevcut kilo kg cinsinden
- targetWeight (number): Hedef kilo kg cinsinden
- activityLevel (string): "sedanter", "az aktif", "orta", "aktif", "çok aktif"
- healthConditions (array): Sağlık sorunları listesi, yoksa boş array
- goals (array): Hedefler listesi (örn: ["kilo verme", "kas geliştirme"])

Sadece JSON formatında cevap ver, başka açıklama yapma:
""";

    try {
      final content = [Content.text(extractPrompt)];
      final response = await _generateContentWithRetry(content);
      final jsonString = response.text ?? '';
      
      // JSON parse etmeye çalış
      final Map<String, dynamic> profileData = jsonDecode(jsonString.trim());
      
      final profile = UserProfile(
        id: _uuid.v4(),
        name: profileData['name'] ?? 'Kullanıcı',
        age: profileData['age'] ?? 25,
        height: (profileData['height'] ?? 170).toDouble(),
        currentWeight: (profileData['currentWeight'] ?? 70).toDouble(),
        targetWeight: (profileData['targetWeight'] ?? 65).toDouble(),
        gender: profileData['gender'] ?? 'erkek',
        activityLevel: profileData['activityLevel'] ?? 'orta',
        healthConditions: List<String>.from(profileData['healthConditions'] ?? []),
        goals: List<String>.from(profileData['goals'] ?? ['genel sağlık']),
      );
      
      await DataService.saveUserProfile(profile);
      print('Profil başarıyla oluşturuldu: ${profile.name}');
    } catch (e) {
      print('Profil oluşturma hatası: $e');
      // Hata durumunda varsayılan profil oluştur
      final profile = UserProfile(
        id: _uuid.v4(),
        name: 'Kullanıcı',
        age: 25,
        height: 170,
        currentWeight: 70,
        targetWeight: 65,
        gender: 'erkek',
        activityLevel: 'orta',
        healthConditions: [],
        goals: ['genel sağlık'],
      );
      await DataService.saveUserProfile(profile);
    }
  }

  static Future<String> _handleExistingUser(String input, List<Map<String, String>> chatHistory, UserProfile profile) async {
    final todayProgress = await DataService.getTodayProgress();
    final totalPoints = await DataService.getTotalPoints();
    final streak = await DataService.getCurrentStreak();

    // Özel komutları kontrol et
    String lowerInput = input.toLowerCase();
    if (lowerInput.contains('bugünün antrenmani') || 
        lowerInput.contains('bugünün antrenmanı') || 
        lowerInput.contains('bugün ne yapacağım') ||
        lowerInput.contains('bugünkü antrenman')) {
      return await _getTodaysWorkout();
    }
    
    if (lowerInput.contains('görevlerim') ||
        lowerInput.contains('tasklerim') ||
        lowerInput.contains('bugünün görevleri') ||
        lowerInput.contains('bugünün taskları')) {
      return await _getTodaysTasks();
    }

    String prompt = """
Sen kişisel sağlık AI asistanısın. Doğrudan ve samimi şekilde konuş.

KULLANICI PROFİLİ:
- Ad: ${profile.name}
- Yaş: ${profile.age}
- Boy: ${profile.height} cm  
- Mevcut Kilo: ${profile.currentWeight} kg
- Hedef Kilo: ${profile.targetWeight} kg
- Cinsiyet: ${profile.gender}
- Aktivite: ${profile.activityLevel}
- Hedefler: ${profile.goals.join(', ')}

MEVCUT DURUM:
- Toplam Puan: $totalPoints
- Mevcut Seri: $streak gün
- Bugün antrenman ${todayProgress?.workoutCompleted == true ? 'tamamlandı ✅' : 'henüz tamamlanmadı ❌'}

Kullanıcının mesajı: $input

YANIT KURALLARI:
❌ YAPMA:
- "Merhaba [isim]" ile başlama
- Kullanıcının söylediklerini tekrarlama 
- "...duydum" gibi ifadeler kullanma
- Uzun giriş cümleleri

✅ YAP:
- Doğrudan konuya gir
- Samimi ve motive edici ol
- Kısa ve etkili cevaplar ver
- Günlük görevleri takip et

ÖZEL KOMUTLAR:
- Kullanıcı "görevlerim" derse günlük görevleri göster
- Kullanıcı görev tamamladığını belirtirse (örn: "şınav yaptım", "su içtim") "TASK_COMPLETED:[görev_açıklaması]" ile başlayan bir mesaj gönder
- Antrenman tamamlandığında "WORKOUT_COMPLETED:" ile başla
- Progress güncellemesi için "UPDATE_PROGRESS:" ile başla
""";

    final content = [Content.text(prompt)];
    final response = await _generateContentWithRetry(content);
    
    String aiResponse = response.text ?? 'Üzgünüm, yanıt oluşturamadım.';
    
    // Özel durumları handle et
    if (aiResponse.startsWith('WORKOUT_COMPLETED:')) {
      await _recordWorkoutCompletion();
      aiResponse = aiResponse.replaceFirst('WORKOUT_COMPLETED:', '').trim();
    } else if (aiResponse.startsWith('UPDATE_PROGRESS:')) {
      // Progress güncelleme işlemi
      aiResponse = aiResponse.replaceFirst('UPDATE_PROGRESS:', '').trim();
    } else if (aiResponse.startsWith('TASK_COMPLETED:')) {
      // Task tamamlama işlemi
      final taskDescription = aiResponse.replaceFirst('TASK_COMPLETED:', '').trim();
      await _handleTaskCompletion(taskDescription);
      aiResponse = '🎉 Harika! Görevi tamamladın ve puan kazandın! \n\nDiğer görevlerin için "görevlerim" yaz. 💪';
    }
    
    return aiResponse;
  }

  static Future<String> _generateDailyTasks() async {
    final profile = await DataService.getUserProfile();
    if (profile == null) return 'Profil bulunamadı.';

    // Günlük taskları oluştur
    await TaskService.generateDailyTasks(profile);
    
    return """
🎉 Harika! ${profile.name}, senin için günlük görevler hazırlandı!

📊 **Kişisel Analiz:**
• Aktivite Seviyesi: ${profile.activityLevel}
• Hedef: ${profile.targetWeight < profile.currentWeight ? 'Kilo verme' : 'Kas geliştirme'}

💪 **Günlük Görev Sistemi:**
• Basit ve ulaşılabilir hedefler
• Her görev için puan kazanma
• Günlük takip ve motivasyon
• Kişiselleştirilmiş zorluk seviyesi

Bugünün görevlerini görmek için "görevlerim" yaz! 📋

Her görevi tamamladığında bana haber ver, puan kazanacaksın! 🏆
""";
  }

  static Future<String> _generateInitialWorkoutPlan() async {
    final profile = await DataService.getUserProfile();
    if (profile == null) return 'Profil bulunamadı.';

    // BMI hesapla
    double bmi = profile.currentWeight / ((profile.height / 100) * (profile.height / 100));
    
    // Kalori ihtiyacı hesapla (Harris-Benedict formülü)
    double bmr;
    if (profile.gender == 'erkek') {
      bmr = 88.362 + (13.397 * profile.currentWeight) + (4.799 * profile.height) - (5.677 * profile.age);
    } else {
      bmr = 447.593 + (9.247 * profile.currentWeight) + (3.098 * profile.height) - (4.330 * profile.age);
    }
    
    // Aktivite faktörü
    double activityFactor;
    switch (profile.activityLevel) {
      case 'sedanter': activityFactor = 1.2; break;
      case 'az aktif': activityFactor = 1.375; break;
      case 'orta': activityFactor = 1.55; break;
      case 'aktif': activityFactor = 1.725; break;
      case 'çok aktif': activityFactor = 1.9; break;
      default: activityFactor = 1.55;
    }
    
    double dailyCalories = bmr * activityFactor;
    
    // Hedef için kalori ayarlaması
    double targetCalories = dailyCalories;
    if (profile.targetWeight < profile.currentWeight) {
      targetCalories -= 500; // Kilo vermek için günlük 500 kalori eksik
    } else if (profile.targetWeight > profile.currentWeight) {
      targetCalories += 300; // Kilo almak için günlük 300 kalori fazla
    }

    String prompt = """
Aşağıdaki kullanıcı profili için 4 haftalık kişiselleştirilmiş calisthenics ve beslenme programı hazırla:

KULLANICI PROFİLİ:
- Ad: ${profile.name}
- Yaş: ${profile.age}
- Cinsiyet: ${profile.gender}
- Boy: ${profile.height} cm
- Mevcut Kilo: ${profile.currentWeight} kg
- Hedef Kilo: ${profile.targetWeight} kg
- BMI: ${bmi.toStringAsFixed(1)}
- Aktivite Seviyesi: ${profile.activityLevel}
- Günlük Kalori İhtiyacı: ${dailyCalories.toInt()} kcal
- Hedef Günlük Kalori: ${targetCalories.toInt()} kcal
- Sağlık Durumu: ${profile.healthConditions.isEmpty ? 'Özel durum yok' : profile.healthConditions.join(', ')}
- Hedefler: ${profile.goals.join(', ')}

PROGRAM GEREKSİNİMLERİ:
1. 4 haftalık ilerleyici calisthenics programı
2. Her hafta için özel odak noktası
3. Haftada 4-5 antrenman günü
4. Her egzersiz için set, tekrar ve süre belirtimi
5. Beslenme önerileri (protein, karbonhidrat, yağ oranları)
6. Günlük kalori ve makro hedefleri

BESLENME ÖNERİLERİ:
- Günlük protein ihtiyacı: ${(profile.currentWeight * 1.6).toInt()}g
- Karbonhidrat: %${profile.targetWeight < profile.currentWeight ? '30-35' : '45-50'}
- Protein: %25-30
- Yağ: %${profile.targetWeight < profile.currentWeight ? '35-40' : '20-25'}

PROGRAM_START: ile başlayarak detaylı program ver. Program şu formatta olsun:

**4 HAFTALIK ${profile.name.toUpperCase()} PROGRAMI**

**BESLENME STRATEJİSİ:**
- Günlük Kalori: ${targetCalories.toInt()} kcal
- Protein: ${(profile.currentWeight * 1.6).toInt()}g
- [Detaylı beslenme önerileri]

**HAFTA 1: [Odak Noktası]**
Pazartesi: [Detaylı antrenman]
Salı: [Dinlenme/Kardio]
[Diğer günler...]

[Diğer haftalar...]
""";

    final content = [Content.text(prompt)];
    final response = await _generateContentWithRetry(content);
    
    String aiResponse = response.text ?? '';
    
    if (aiResponse.startsWith('PROGRAM_START:')) {
      await _saveWorkoutPlanFromAI(aiResponse, profile);
      return """
🎉 Mükemmel! ${profile.name}, senin için özel 4 haftalık program hazırlandı!

📊 **Kişisel Analiz:**
• BMI: ${bmi.toStringAsFixed(1)} 
• Günlük Kalori İhtiyacı: ${targetCalories.toInt()} kcal
• Günlük Protein Hedefi: ${(profile.currentWeight * 1.6).toInt()}g

💪 **Program Özellikleri:**
• 4 haftalık ilerleyici calisthenics
• Beslenme rehberi dahil
• Haftalık ilerleme takibi
• Kişiselleştirilmiş set/tekrar sayıları

Programın başladı! Her gün sana o günün antrenmanını soracağım ve tamamladığında puan kazanacaksın! 🏆

Bugünün antrenmanını görmek ister misin? "Bugünün antrenmanı" yaz! 💪
""";
    }
    
    return aiResponse;
  }

  static Future<void> _saveWorkoutPlanFromAI(String aiResponse, UserProfile profile) async {
    // AI'dan gelen metni parse edip workout plan oluştur
    final plan = WorkoutPlan(
      id: _uuid.v4(),
      userId: profile.id,
      title: '${profile.name} için Özel Program',
      description: 'Kişiselleştirilmiş 4 haftalık calisthenics ve beslenme programı',
      durationWeeks: 4,
      weeks: _createPersonalizedWeeks(profile),
    );
    
    await DataService.saveWorkoutPlan(plan);
  }

  static List<WeeklyPlan> _createPersonalizedWeeks(UserProfile profile) {
    // Kullanıcı seviyesine göre egzersiz zorlukları
    int baseReps = _getBaseRepsForLevel(profile);
    int baseSets = _getBaseSetsForLevel(profile);
    
    return [
      WeeklyPlan(
        weekNumber: 1,
        focus: 'Temel Hareketler ve Vücut Alışkanlığı',
        dailyWorkouts: _createWeekWorkouts(1, baseReps, baseSets, profile),
      ),
      WeeklyPlan(
        weekNumber: 2,
        focus: 'Yoğunluk Artırma ve Form Geliştirme',
        dailyWorkouts: _createWeekWorkouts(2, baseReps + 2, baseSets, profile),
      ),
      WeeklyPlan(
        weekNumber: 3,
        focus: 'Güç ve Dayanıklılık Geliştirme',
        dailyWorkouts: _createWeekWorkouts(3, baseReps + 4, baseSets + 1, profile),
      ),
      WeeklyPlan(
        weekNumber: 4,
        focus: 'Maximum Performans ve Değerlendirme',
        dailyWorkouts: _createWeekWorkouts(4, baseReps + 6, baseSets + 1, profile),
      ),
    ];
  }

  static int _getBaseRepsForLevel(UserProfile profile) {
    // Yaş, aktivite seviyesi ve hedeflere göre başlangıç tekrar sayısı
    int baseReps = 8;
    
    if (profile.activityLevel == 'sedanter') baseReps = 5;
    else if (profile.activityLevel == 'az aktif') baseReps = 6;
    else if (profile.activityLevel == 'orta') baseReps = 8;
    else if (profile.activityLevel == 'aktif') baseReps = 10;
    else if (profile.activityLevel == 'çok aktif') baseReps = 12;
    
    // Yaş ayarlaması
    if (profile.age > 40) baseReps -= 2;
    if (profile.age > 50) baseReps -= 2;
    
    return baseReps < 5 ? 5 : baseReps;
  }

  static int _getBaseSetsForLevel(UserProfile profile) {
    return profile.activityLevel == 'sedanter' || profile.age > 50 ? 2 : 3;
  }

  static List<DailyWorkout> _createWeekWorkouts(int week, int reps, int sets, UserProfile profile) {
    final bool isWeightLoss = profile.targetWeight < profile.currentWeight;
    
    return [
      // Pazartesi - Üst Vücut
      DailyWorkout(
        dayNumber: 1,
        dayName: 'Pazartesi',
        type: 'workout',
        title: 'Üst Vücut Güçlendirme',
        description: 'Göğüs, omuz ve triceps odaklı antrenman',
        exercises: [
          Exercise(
            name: 'Push-up (Şınav)',
            description: 'Standart şınav, dizler üzerinde varvasyon mümkün',
            sets: sets,
            reps: reps,
            notes: 'Doğru form önemli, yorulduğunda diz üstü yapabilirsin',
          ),
          Exercise(
            name: 'Pike Push-up',
            description: 'Kalçalar yukarıda, omuz odaklı şınav',
            sets: sets - 1,
            reps: reps - 2,
            notes: 'Omuz geliştirme için harika egzersiz',
          ),
          Exercise(
            name: 'Tricep Dips',
            description: 'Sandalye veya yüksek yüzeyde tricep çalışması',
            sets: sets,
            reps: reps,
            notes: 'Dirsekleri vücuda yakın tut',
          ),
          Exercise(
            name: 'Plank',
            description: 'Karın ve core stability',
            sets: 3,
            duration: 30 + (week * 10),
            notes: 'Vücut düz bir çizgi halinde olsun',
          ),
        ],
      ),
      
      // Salı - Aktif Dinlenme/Kardio
      DailyWorkout(
        dayNumber: 2,
        dayName: 'Salı',
        type: isWeightLoss ? 'cardio' : 'rest',
        title: isWeightLoss ? 'Kardio Günü' : 'Aktif Dinlenme',
        description: isWeightLoss ? 'Yağ yakımı odaklı kardio' : 'Hafif aktivite ve esneklik',
        exercises: isWeightLoss ? [
          Exercise(
            name: 'Yürüyüş/Koşu',
            description: 'Orta tempoda kardio',
            duration: 20 + (week * 5),
            notes: 'Nefes almakta zorlanmayacağın tempo',
          ),
          Exercise(
            name: 'Jumping Jacks',
            description: 'Koordinasyon ve kardio',
            sets: 3,
            reps: 15 + (week * 5),
            notes: 'Dinamik hareket',
          ),
        ] : [
          Exercise(
            name: 'Hafif Yürüyüş',
            description: 'Rahatlatıcı tempo',
            duration: 15,
            notes: 'Kasları gevşetmek için',
          ),
          Exercise(
            name: 'Stretching',
            description: 'Genel vücut esnekliği',
            duration: 10,
            notes: 'Özellikle üst vücut kas grupları',
          ),
        ],
      ),

      // Çarşamba - Alt Vücut
      DailyWorkout(
        dayNumber: 3,
        dayName: 'Çarşamba',
        type: 'workout',
        title: 'Alt Vücut ve Bacak Gücü',
        description: 'Quadriceps, glutes ve hamstring çalışması',
        exercises: [
          Exercise(
            name: 'Squat (Çömelme)',
            description: 'Temel bacak egzersizi',
            sets: sets,
            reps: reps + 3,
            notes: 'Kalçalar arkaya, dizler parmak uçlarını geçmesin',
          ),
          Exercise(
            name: 'Lunges (Öne Adım)',
            description: 'Alternatif bacaklarla öne adım',
            sets: sets,
            reps: reps * 2, // Her bacak için
            notes: 'Denge ve koordinasyon geliştirir',
          ),
          Exercise(
            name: 'Glute Bridge',
            description: 'Kalça kaldırma hareketi',
            sets: sets,
            reps: reps + 2,
            notes: 'Kalça kaslarını sıkıştır',
          ),
          Exercise(
            name: 'Calf Raises',
            description: 'Baldır kası çalışması',
            sets: 3,
            reps: reps + 5,
            notes: 'Parmak uçlarında yüksek',
          ),
        ],
      ),

      // Perşembe - Dinlenme
      DailyWorkout(
        dayNumber: 4,
        dayName: 'Perşembe',
        type: 'rest',
        title: 'Tam Dinlenme',
        description: 'Vücut onarımı ve toparlanma günü',
        exercises: [],
      ),

      // Cuma - Full Body
      DailyWorkout(
        dayNumber: 5,
        dayName: 'Cuma',
        type: 'workout',
        title: 'Tüm Vücut Kombine Antrenman',
        description: 'Üst ve alt vücut kombinasyonu',
        exercises: [
          Exercise(
            name: 'Burpees',
            description: 'Tam vücut cardiovascular egzersiz',
            sets: sets - 1,
            reps: reps - 3,
            notes: 'Yoğun ama etkili, modifiye edebilirsin',
          ),
          Exercise(
            name: 'Mountain Climbers',
            description: 'Plank pozisyonunda koşu hareketi',
            sets: 3,
            duration: 30 + (week * 5),
            notes: 'Core ve kardio kombinasyonu',
          ),
          Exercise(
            name: 'Superman',
            description: 'Sırt kasları güçlendirme',
            sets: sets,
            reps: reps,
            notes: 'Sırt sağlığı için önemli',
          ),
          Exercise(
            name: 'Side Plank',
            description: 'Yan karın kasları',
            sets: 2,
            duration: 20 + (week * 5),
            notes: 'Her iki yan için',
          ),
        ],
      ),

      // Cumartesi - Aktif Dinlenme
      DailyWorkout(
        dayNumber: 6,
        dayName: 'Cumartesi',
        type: 'cardio',
        title: 'Aktif Toparlanma',
        description: 'Hafif aktivite ve esneklik',
        exercises: [
          Exercise(
            name: 'Yoga/Stretching',
            description: 'Esneklik ve gevşeme',
            duration: 20,
            notes: 'Haftanın yorgunluğunu at',
          ),
          Exercise(
            name: 'Hafif Yürüyüş',
            description: 'Doğada veya evde',
            duration: 15,
            notes: 'Zihinsel olarak da rahatlat',
          ),
        ],
      ),

      // Pazar - Dinlenme
      DailyWorkout(
        dayNumber: 7,
        dayName: 'Pazar',
        type: 'rest',
        title: 'Haftalık Dinlenme',
        description: 'Tam dinlenme ve değerlendirme günü',
        exercises: [],
      ),
    ];
  }

  static Future<void> _handleTaskCompletion(String taskDescription) async {
    // Task açıklamasına göre ilgili görevi bul ve tamamla
    final tasks = await TaskService.getTodaysTasks();
    
    // Basit kelime eşleştirmesi ile task bul
    String lowerDescription = taskDescription.toLowerCase();
    DailyTask? matchedTask;
    
    for (var task in tasks) {
      if (task.completed) continue; // Zaten tamamlanmış ise atla
      
      String taskName = task.name.toLowerCase();
      String taskDesc = task.description.toLowerCase();
      
      // Anahtar kelimelerle eşleştir
      if ((lowerDescription.contains('şınav') && (taskName.contains('şınav') || taskDesc.contains('şınav'))) ||
          (lowerDescription.contains('squat') && (taskName.contains('squat') || taskDesc.contains('squat'))) ||
          (lowerDescription.contains('plank') && (taskName.contains('plank') || taskDesc.contains('plank'))) ||
          (lowerDescription.contains('yürü') && (taskName.contains('yürü') || taskDesc.contains('yürü'))) ||
          (lowerDescription.contains('su') && (taskName.contains('su') || taskDesc.contains('su'))) ||
          (lowerDescription.contains('protein') && (taskName.contains('protein') || taskDesc.contains('protein'))) ||
          (lowerDescription.contains('kahvaltı') && (taskName.contains('kahvaltı') || taskDesc.contains('kahvaltı'))) ||
          (lowerDescription.contains('sebze') && (taskName.contains('sebze') || taskDesc.contains('sebze'))) ||
          (lowerDescription.contains('uyku') && (taskName.contains('uyku') || taskDesc.contains('uyku')))) {
        matchedTask = task;
        break;
      }
    }
    
    if (matchedTask != null) {
      await TaskService.completeTask(matchedTask.id);
    }
  }

  static Future<void> _recordWorkoutCompletion() async {
    final today = DateTime.now();
    final todayProgress = await DataService.getTodayProgress();
    
    final points = 10; // Her antrenman için 10 puan
    
    final newProgress = todayProgress?.copyWith(
      workoutCompleted: true,
      totalPoints: (todayProgress.totalPoints) + points,
    ) ?? ProgressEntry(
      id: _uuid.v4(),
      userId: (await DataService.getUserProfile())?.id ?? '',
      date: today,
      workoutCompleted: true,
      totalPoints: points,
    );
    
    await DataService.saveProgressEntry(newProgress);
  }

  static Future<String> getDailyWorkout() async {
    final workoutPlan = await DataService.getWorkoutPlan();
    if (workoutPlan == null) return 'Henüz bir program oluşturulmamış.';
    
    final today = DateTime.now();
    final dayOfWeek = today.weekday; // 1 = Pazartesi, 7 = Pazar
    final currentWeek = await DataService.getCurrentWeekNumber();
    
    if (currentWeek > workoutPlan.weeks.length) {
      return 'Tebrikler! Programını tamamladın! 🎉';
    }
    
    final week = workoutPlan.weeks[currentWeek - 1];
    final dailyWorkout = week.dailyWorkouts.firstWhere(
      (workout) => workout.dayNumber == dayOfWeek,
      orElse: () => week.dailyWorkouts.first,
    );
    
    if (dailyWorkout.type == 'rest') {
      return '🛌 Bugün dinlenme günün! Vücudunu dinlendir ve yarına hazırlan.';
    }
    
    String workoutText = '💪 **${dailyWorkout.title}**\n\n${dailyWorkout.description}\n\n';
    
    for (var exercise in dailyWorkout.exercises) {
      workoutText += '• **${exercise.name}**: ';
      if (exercise.sets != null && exercise.reps != null) {
        workoutText += '${exercise.sets} set x ${exercise.reps} tekrar\n';
      } else if (exercise.duration != null) {
        workoutText += '${exercise.duration} saniye\n';
      }
      workoutText += '  ${exercise.description}\n\n';
    }
    
    workoutText += 'Antrenmanını tamamladığında bana haber ver! 🏆';
    
    return workoutText;
  }

  static Future<String> _getTodaysTasks() async {
    final profile = await DataService.getUserProfile();
    if (profile == null) return 'Profil bulunamadı. Önce profil oluşturalım!';

    // Günlük taskları oluştur veya getir
    await TaskService.generateDailyTasks(profile);
    return await TaskService.getTasksSummary();
  }

  static Future<String> _getTodaysWorkout() async {
    final profile = await DataService.getUserProfile();
    if (profile == null) return 'Profil bulunamadı. Önce profil oluşturalım!';

    final plan = await DataService.getWorkoutPlan();
    if (plan == null) return 'Henüz bir programın yok. Program oluşturmak ister misin?';

    // Hangi haftada olduğumuzu hesapla
    final startDate = profile.createdAt;
    final now = DateTime.now();
    final daysSinceStart = now.difference(startDate).inDays;
    final currentWeek = (daysSinceStart ~/ 7) + 1;
    final dayOfWeek = daysSinceStart % 7;

    if (currentWeek > plan.weeks.length) {
      return """
🎉 Tebrikler! ${plan.durationWeeks} haftalık programını tamamladın!

📊 **Başarıların:**
• Program süresi: ${plan.durationWeeks} hafta
• Başlangıç: ${profile.currentWeight} kg
• Hedef: ${profile.targetWeight} kg

Yeni bir program oluşturmak ister misin? Yoksa mevcut programı tekrarlamak? 💪
""";
    }

    final weeklyPlan = plan.weeks[currentWeek - 1];
    final todaysWorkout = weeklyPlan.dailyWorkouts[dayOfWeek];

    // Bugünün durumunu kontrol et
    final todayProgress = await DataService.getTodayProgress();
    
    String statusMessage = '';
    if (todayProgress != null && todayProgress.workoutCompleted) {
      statusMessage = '✅ Bugünün antrenmanını tamamladın! Süpersin! 🎉\n\n';
    }

    String workoutMessage = _formatTodaysWorkout(
      currentWeek, 
      weeklyPlan, 
      todaysWorkout, 
      todayProgress?.workoutCompleted ?? false
    );

    return statusMessage + workoutMessage;
  }

  static String _formatTodaysWorkout(int week, WeeklyPlan weeklyPlan, DailyWorkout workout, bool isCompleted) {
    String message = """
📅 **HAFTA $week - ${workout.dayName.toUpperCase()}**
🎯 **Haftalık Odak:** ${weeklyPlan.focus}

💪 **${workout.title}**
${workout.description}

""";

    if (workout.type == 'rest') {
      message += """
🛌 **Dinlenme Günü**
Bugün vücudun toparlanma zamanı! 

✨ **Öneriler:**
• Bol su iç (en az 2 litre)
• Hafif yürüyüş yap
• Kaslarını gerdirme hareketleri yap
• Kaliteli uyku al (7-8 saat)

${isCompleted ? '' : 'Dinlenme gününü tamamlamak için "tamamladım" yaz! 😊'}
""";
    } else if (workout.type == 'cardio') {
      message += "🏃 **Kardio Günü**\n\n";
      for (var exercise in workout.exercises) {
        message += _formatExercise(exercise);
      }
      if (!isCompleted) {
        message += "\n💡 Kardio antrenmanını tamamladığında 'tamamladım' yaz!";
      }
    } else {
      message += "🏋️ **Antrenman Günü**\n\n";
      for (var exercise in workout.exercises) {
        message += _formatExercise(exercise);
      }
      
      if (!isCompleted) {
        message += """

🔥 **Antrenman Tamamlandığında:**
'tamamladım' yazarak puan kazan ve ilerlemeni kaydet! 

💡 **İpuçları:**
• Hareketleri yavaş ve kontrollü yap
• Nefes almayı unutma
• Su iç
• Ağrı hissedersen dur
""";
      }
    }

    return message;
  }

  static String _formatExercise(Exercise exercise) {
    String exerciseText = "🔸 **${exercise.name}**\n";
    exerciseText += "   ${exercise.description}\n";
    
    if ((exercise.sets ?? 0) > 0) {
      if ((exercise.reps ?? 0) > 0) {
        exerciseText += "   📊 ${exercise.sets} set × ${exercise.reps} tekrar\n";
      } else if ((exercise.duration ?? 0) > 0) {
        exerciseText += "   ⏱️ ${exercise.sets} set × ${exercise.duration} saniye\n";
      }
    } else if ((exercise.duration ?? 0) > 0) {
      exerciseText += "   ⏱️ ${exercise.duration} saniye\n";
    }
    
    if (exercise.notes?.isNotEmpty == true) {
      exerciseText += "   💭 ${exercise.notes}\n";
    }
    
    exerciseText += "\n";
    return exerciseText;
  }
}
