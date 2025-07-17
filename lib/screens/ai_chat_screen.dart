import 'package:flutter/material.dart';
import '../widgets/input_field.dart';
import '../widgets/message_bubble.dart';
import '../models/chat_message.dart';
import '../services/health_ai_service.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeHealthAI();
  }

  Future<void> _initializeHealthAI() async {
    try {
      await HealthAIService.initialize();
      
      // Hoş geldin mesajını al
      final welcomeMessage = await HealthAIService.getWelcomeMessage();
      
      setState(() {
        _messages.add(
          ChatMessage(
            text: welcomeMessage,
            isUser: false,
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sağlık AI başlatılamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Kullanıcı mesajını ekle
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    // Scroll to bottom
    _scrollToBottom();

    try {
      // Chat geçmişini hazırla
      final chatHistory = _messages
          .where((msg) => msg != _messages.last) // Son mesajı (şu anki) hariç tut
          .map((msg) => msg.toMap())
          .toList();

      // Health AI'den yanıt al
      final response = await HealthAIService.processUserInput(
        text,
        chatHistory,
      );

      // AI yanıtını ekle
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        String errorMessage = "Üzgünüm, bir hata oluştu. Lütfen tekrar deneyin.";
        
        // Spesifik hata mesajları
        if (e.toString().contains('503') || e.toString().contains('overloaded')) {
          errorMessage = "Sunucu şu anda aşırı yüklenmiş. Lütfen birkaç saniye bekleyip tekrar deneyin.";
        } else if (e.toString().contains('API key')) {
          errorMessage = "API anahtarı sorunu. Lütfen ayarları kontrol edin.";
        } else if (e.toString().contains('network') || e.toString().contains('internet')) {
          errorMessage = "İnternet bağlantısı sorunu. Lütfen bağlantınızı kontrol edin.";
        }
        
        _messages.add(
          ChatMessage(
            text: errorMessage,
            isUser: false,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showDailyTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chatHistory = _messages.map((msg) => msg.toMap()).toList();
      final response = await HealthAIService.processUserInput('görevlerim', chatHistory);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: "Görevler yüklenirken hata oluştu.", isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _showDailyWorkout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final workout = await HealthAIService.getDailyWorkout();
      setState(() {
        _messages.add(ChatMessage(text: workout, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Antrenman bilgisi alınamadı: $e",
            isUser: false,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Sağlık AI Coach",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.task_alt, color: Colors.white),
            onPressed: _showDailyTasks,
            tooltip: "Bugünün Görevleri",
          ),
          IconButton(
            icon: const Icon(Icons.fitness_center, color: Colors.white),
            onPressed: _showDailyWorkout,
            tooltip: "Bugünün Antrenmanı",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      "Sağlık AI Coach'unuz yükleniyor...",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(message: _messages[index]);
                    },
                  ),
          ),
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Sağlık AI düşünüyor...",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          InputField(
            onSend: _sendMessage,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}
