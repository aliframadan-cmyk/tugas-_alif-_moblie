import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  String _response = "How can ALIFORNIA ai help?";
  bool _loading = false;
  String? _modelName;

  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _typingController.dispose();
    super.dispose();
  }

  Future<void> _loadValidModel(String apiKey) async {
    final uri = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey",
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("Gagal mengambil daftar model: ${res.body}");
    }

    final data = jsonDecode(res.body);
    final models = data["models"] as List<dynamic>;

    for (final m in models) {
      final methods = (m["supportedGenerationMethods"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
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
      setState(() => _response = "❌ API Key tidak ditemukan di .env");
      return;
    }

    setState(() {
      _loading = true;
      _response = "AI sedang berpikir";
    });

    try {
      _modelName ??= (await () async {
        await _loadValidModel(apiKey);
        return _modelName!;
      }());

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
                {
                  "text":
                      "Kamu adalah pakar sejarah Indonesia. Jawab dengan jelas:\n$question"
                }
              ]
            }
          ]
        }),
      );

      final data = jsonDecode(res.body);
      setState(() {
        _response =
            data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ??
                "⚠️ Tidak ada jawaban dari AI.";
      });
    } catch (e) {
      setState(() => _response = "❌ Error: $e");
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
            colors: [
              Color.fromARGB(255, 15, 3, 237),
              Color.fromARGB(255, 43, 3, 188),
              Color.fromARGB(255, 0, 14, 67),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.6),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.smart_toy_rounded,
                          color: Color.fromARGB(255, 16, 4, 244),
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      "ALIFORIA AI Sejarah Indonesia",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: _loading
                          ? AnimatedBuilder(
                              animation: _typingController,
                              builder: (_, __) {
                                final dots = "." *
                                    ((_typingController.value * 3).ceil());
                                return Text(
                                  "AI sedang berpikir$dots",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              },
                            )
                          : Text(
                              _response,
                              style: const TextStyle(
                                fontSize: 16.5,
                                height: 1.7,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: "Enter the command for ALIFORIA...",
                            border: InputBorder.none,
                          ),
                          onSubmitted: _askAI,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Color.fromARGB(255, 14, 3, 238),
                        ),
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