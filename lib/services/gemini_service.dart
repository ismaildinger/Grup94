import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static late GenerativeModel _model;
  static bool _initialized = false;

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
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );
      
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Gemini AI: $e');
    }
  }

  static Future<String> generateResponse(String prompt) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'Üzgünüm, bir yanıt oluşturamadım.';
    } catch (e) {
      return 'Hata oluştu: $e';
    }
  }

  static Future<String> generateResponseWithContext(
    List<Map<String, String>> chatHistory,
    String newMessage,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Chat geçmişini context olarak hazırla
      String context = '';
      for (var message in chatHistory) {
        if (message['role'] == 'user') {
          context += 'Kullanıcı: ${message['content']}\n';
        } else {
          context += 'Asistan: ${message['content']}\n';
        }
      }
      
      // Yeni mesajı ekle
      context += 'Kullanıcı: $newMessage\n';
      context += 'Asistan:';

      final content = [Content.text(context)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'Üzgünüm, bir yanıt oluşturamadım.';
    } catch (e) {
      return 'Hata oluştu: $e';
    }
  }
}
