import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Memastikan file .env terbaca
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("File .env tidak ditemukan: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  String _response = "Silakan tanya sejarah Indonesia.";
  bool _loading = false;
  String? _modelName;
  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 1)
    )..repeat();
  }

  @override
  void dispose() {
    _typingController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Fungsi untuk mendapatkan model yang tersedia (Gemini 1.5, dll)
  Future<void> _loadValidModel(String apiKey) async {
    final uri = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey",
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("Gagal memuat model. Status: ${res.statusCode}");
    }

    final data = jsonDecode(res.body);
    final models = data["models"] as List<dynamic>;

    for (final m in models) {
      final methods = (m["supportedGenerationMethods"] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      if (methods.contains("generateContent")) {
        _modelName = m["name"];
        break;
      }
    }
  }

  Future<void> _askAI(String question) async {
    if (question.trim().isEmpty) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _response = "❌ Error: API Key tidak ditemukan di file .env");
      return;
    }

    setState(() {
      _loading = true;
      _response = "AI sedang berpikir";
    });

    try {
      // Inisialisasi model jika belum ada
      if (_modelName == null) {
        await _loadValidModel(apiKey);
      }

      final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/$_modelName:generateContent?key=$apiKey",
      );

      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "Kamu adalah pakar sejarah Indonesia. Jawab pertanyaan ini dengan akurat: $question"}
              ]
            }
          ]
        }),
      );

      final data = jsonDecode(res.body);

      setState(() {
        if (res.statusCode == 200) {
          // Navigasi JSON yang aman agar AI bisa 'membaca' response
          if (data["candidates"] != null && data["candidates"].isNotEmpty) {
            _response = data["candidates"][0]["content"]["parts"][0]["text"];
          } else {
            _response = "⚠️ AI tidak memberikan jawaban. Detail: ${res.body}";
          }
        } else {
          _response = "❌ Error ${res.statusCode}: ${data['error']?['message'] ?? 'Gagal menghubungi AI'}";
        }
      });
    } catch (e) {
      setState(() => _response = "❌ Terjadi kesalahan koneksi: $e");
    } finally {
      setState(() {
        _loading = false;
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFFB39DFF), Color(0xFFF6F7FB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header UI
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.smart_toy_rounded, color: Color(0xFF6C63FF)),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      "Pakar Sejarah AI",
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Area Tampilan Pesan
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SingleChildScrollView(
                      child: _loading
                          ? AnimatedBuilder(
                              animation: _typingController,
                              builder: (_, __) {
                                final dots = "." * ((_typingController.value * 3).ceil());
                                return Text("AI sedang berpikir$dots", 
                                    style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic));
                              },
                            )
                          : Text(_response, style: const TextStyle(fontSize: 16, height: 1.6)),
                    ),
                  ),
                ),
              ),
              // Input Chat
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: "Tanyakan sejarah Indonesia...",
                            border: InputBorder.none,
                          ),
                          onSubmitted: _askAI,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF)),
                        onPressed: () => _askAI(_controller.text),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}