import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';

// Глобальний список камер
List<CameraDescription> cameras = [];

Future<void> initCameras() async {
  if (cameras.isEmpty) {
    cameras = await availableCameras();
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    await initCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  Future<void> _takeAndAnalyze() async {
    if (_isAnalyzing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final image = await _controller!.takePicture();
      final userId = await AuthService.getStoredUserId();

      // Відправка на бекенд для аналізу
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AuthService.baseUrl}/analyze_image'),
      );

      request.fields['user_id'] = userId ?? "";
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var streamedRes = await request.send();
      var res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final result = jsonDecode(res.body);
        if (mounted) _showResult(result);
      } else {
        throw Exception("Server Error: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Помилка аналізу: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showResult(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnalysisResultSheet(analysisData: data),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),

          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 260,
                    width: 260,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Align(
            alignment: Alignment.center,
            child: Container(
              height: 260,
              width: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2.5),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),

          if (_isAnalyzing) _LoadingOverlay(),

          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _takeAndAnalyze,
                  child: Container(
                    height: 85,
                    width: 85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 5),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "СКАСУВАТИ",
                    style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingOverlay extends StatefulWidget {
  @override
  State<_LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<_LoadingOverlay> {
  int _step = 0;
  final List<String> _texts = [
    "Розпізнаю продукти...",
    "Рахую калорії...",
    "Майже готово...",
  ];
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (mounted) setState(() => _step = (_step + 1) % _texts.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.greenAccent,
                strokeWidth: 6,
              ),
              const SizedBox(height: 30),
              Text(
                _texts[_step],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === ВИПРАВЛЕНА ЧАСТИНА ===
class _AnalysisResultSheet extends StatelessWidget {
  final Map<String, dynamic> analysisData;
  const _AnalysisResultSheet({required this.analysisData});

  Future<void> _addMealToDb(BuildContext context) async {
    try {
      final userId = await AuthService.getStoredUserId();

      // 1. Очищення даних перед відправкою
      // Деякі API можуть повертати дробові числа для калорій, але ми хочемо int
      final int calories = (analysisData['calories'] as num).round();
      final double protein = (analysisData['protein'] as num).toDouble();
      final double fat = (analysisData['fat'] as num).toDouble();
      final double carbs = (analysisData['carbs'] as num).toDouble();

      final bodyData = {
        "user_id": userId,
        "meal_name": analysisData['meal_name'] ?? "Аналіз фото",
        "calories": calories,
        "protein": protein,
        "fat": fat,
        "carbs": carbs,
        // Якщо сервер повернув image_url, передаємо його, інакше null
        "image_url": analysisData['image_url'],
        // Додаємо дату, про всяк випадок
        "created_at": DateTime.now().toIso8601String(),
      };

      debugPrint("Sending Manual Meal: ${jsonEncode(bodyData)}");

      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/add_manual_meal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200) {
        if (!context.mounted) return;
        Navigator.pop(context); // Закрити панель
        Navigator.pop(context); // Повернутись на головну
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Смачного! Додано в раціон."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        debugPrint(
          "Error adding meal: ${response.statusCode} - ${response.body}",
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Помилка збереження: ${response.statusCode}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Add meal exception: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final calories = analysisData['calories']?.toString() ?? "0";
    final mealName = analysisData['meal_name'] ?? "Знайдена страва";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            mealName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 25),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroInfo("Білки", analysisData['protein'], Colors.blueAccent),
              _macroInfo("Жири", analysisData['fat'], Colors.orangeAccent),
              _macroInfo("Вугл.", analysisData['carbs'], Colors.purpleAccent),
            ],
          ),

          const SizedBox(height: 40),
          Text(
            "$calories ккал",
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 40),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 60),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text("ЩЕ ФОТО"),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _addMealToDb(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    minimumSize: const Size(0, 60),
                  ),
                  child: const Text(
                    "З'ЇВ",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroInfo(String label, dynamic val, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "${val ?? 0}г",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
