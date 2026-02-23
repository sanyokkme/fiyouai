import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';

class AILoggerScreen extends StatefulWidget {
  const AILoggerScreen({super.key});

  @override
  State<AILoggerScreen> createState() => _AILoggerScreenState();
}

class _AILoggerScreenState extends State<AILoggerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  // States:
  // 0 = idle
  // 1 = recording
  // 4 = editing text
  // 2 = analyzing text (calling backend save_to_db=false)
  // 5 = review macros
  // 6 = saving to DB (calling backend save_to_db=true)
  // 3 = success
  int _currentState = 0;
  bool _showInfoOverlay = false;

  String _recognizedText = "";
  String _finalResponse = "";

  // Data from backend
  String _mealName = "";
  int _calories = 0;
  double _protein = 0;
  double _fat = 0;
  double _carbs = 0;

  late stt.SpeechToText _speech;
  bool _isSpeechInitialized = false;

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint('Microphone permission not granted');
    }

    _isSpeechInitialized = await _speech.initialize(
      onError: (val) => debugPrint('Speech Error: ${val.errorMsg}'),
      onStatus: (val) {
        if (val == 'done' && _currentState == 1) {
          _stopRecordingAndEdit();
        }
      },
    );
    setState(() {});
  }

  void _startRecording() async {
    if (!_isSpeechInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Помилка доступу до мікрофону')),
      );
      return;
    }

    setState(() {
      _currentState = 1;
      _recognizedText = "";
      _finalResponse = "";
    });

    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (val) {
        if (mounted) {
          setState(() {
            _recognizedText = val.recognizedWords;
          });
        }
      },
      localeId: 'uk_UA',
      cancelOnError: true,
      partialResults: true,
    );
  }

  void _stopRecordingAndEdit() async {
    if (_currentState != 1) return;

    _pulseController.stop();
    await _speech.stop();

    if (_recognizedText.trim().isEmpty) {
      setState(() {
        _currentState = 0;
      });
      return;
    }

    _switchToEditMode(_recognizedText);
  }

  void _switchToEditMode(String initialText) {
    _textController.text = initialText;
    setState(() {
      _currentState = 4; // Editing
    });
  }

  Future<void> _analyzeText(String text) async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) {
      setState(() {
        _finalResponse = "Помилка авторизації.";
        _currentState = 3;
      });
      return;
    }

    setState(() {
      _currentState = 2; // Processing
      _recognizedText = text;
    });

    try {
      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/analyze_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": userId,
          "text": text,
          "save_to_db": false,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _mealName = data['meal_name'] ?? 'Не вдалося розпізнати';
        _calories = data['calories'] ?? 0;
        _protein = (data['protein'] ?? 0).toDouble();
        _fat = (data['fat'] ?? 0).toDouble();
        _carbs = (data['carbs'] ?? 0).toDouble();

        if (_calories == 0) {
          setState(() {
            _finalResponse =
                "На жаль, я не зміг розпізнати тут їжу. Спробуйте ще раз.";
            _currentState = 3;
          });
        } else {
          setState(() {
            _currentState = 5; // Review Macros
          });
        }
      } else {
        setState(() {
          _finalResponse = "Сталася помилка на сервері (${res.statusCode}).";
          _currentState = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _finalResponse = "Помилка з'єднання.\n$e";
          _currentState = 3;
        });
      }
    }
  }

  Future<void> _saveToDb(String text) async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    setState(() {
      _currentState = 6; // Saving
    });

    try {
      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/analyze_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": userId, "text": text, "save_to_db": true}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() {
          _finalResponse =
              "Збережено: $_mealName\n🔥 $_calories ккал  |  Б:$_protein  Ж:$_fat  В:$_carbs";
          _currentState = 3;
        });
      } else {
        setState(() {
          _finalResponse = "Помилка при збереженні (${res.statusCode}).";
          _currentState = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _finalResponse = "Помилка з'єднання при збереженні.\n$e";
          _currentState = 3;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.cancel();
    _textController.dispose();
    super.dispose();
  }

  // --- UI Build Helpers ---

  Widget _buildTopNavyBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              bool addedSomething =
                  _currentState == 3 && _finalResponse.contains("Збережено");
              Navigator.pop(context, addedSomething);
            },
            child: const Icon(Icons.close, color: Colors.white, size: 28),
          ),

          // Center Pill — "Інформація"
          GestureDetector(
            onTap: () {
              setState(() {
                _showInfoOverlay = !_showInfoOverlay;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Інформація",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showInfoOverlay
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      crossFadeState: _showInfoOverlay
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      secondChild: const SizedBox.shrink(),
      firstChild: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Як працює AI Logger?",
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "1. Утримуйте кнопку мікрофону та опишіть, що ви з'їли.\n"
              "2. Після відпускання ви зможете перевірити та відредагувати текст.\n"
              "3. Натисніть 'Аналізувати' — штучний інтелект розпізнає страву та розрахує калорії, білки, жири та вуглеводи.\n"
              "4. Перегляньте результат та підтвердіть додавання до раціону.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Також можна натиснути іконку клавіатури, щоб ввести страву вручну.",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedRing() {
    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            // A subtle pulse for the ring
            double scale = _currentState == 1
                ? 1.0 + (_pulseController.value * 0.1)
                : 1.0;

            return Transform.scale(
              scale: scale,
              child: CustomPaint(
                painter: DottedRingPainter(
                  isRecording: _currentState == 1,
                  animationValue: _pulseController.value,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainText() {
    if (_currentState == 4) {
      // Editable Text Field UI
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: null,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: "Що ви з'їли?",
                hintStyle: const TextStyle(color: Colors.white54),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentState = 0;
                    });
                  },
                  child: const Text(
                    "Скасувати",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_textController.text.trim().isNotEmpty) {
                      _analyzeText(_textController.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Аналізувати",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_currentState == 5) {
      // Review Macros UI
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            Text(
              "Я розпізнав:\n$_mealName",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.5),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "$_calories ккал\nБ: $_protein г  |  Ж: $_fat г  |  В: $_carbs г",
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Додати до сьогоднішнього раціону?",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentState = 0; // Cancel, go back to start
                    });
                  },
                  child: const Text(
                    "Скасувати",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => _saveToDb(_recognizedText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Так, додати",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    String displayStr;
    Color textColor = Colors.white;

    if (_currentState == 0) {
      displayStr =
          "Опишіть вашу страву: наприклад, 'Я з'їв салат і шматок курки'.";
      textColor = Colors.white54;
    } else if (_currentState == 1) {
      displayStr = _recognizedText.isEmpty ? "Слухаю..." : _recognizedText;
    } else if (_currentState == 2 || _currentState == 6) {
      displayStr = "Обробка інформації...";
      textColor = Colors.white70;
    } else {
      displayStr = _finalResponse;
      textColor = _finalResponse.contains("Збережено")
          ? const Color(0xFF4CAF50)
          : Colors.redAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        displayStr,
        style: TextStyle(
          color: textColor,
          fontSize: 22,
          height: 1.4,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatusText() {
    String status = "Готово до запису";
    if (_currentState == 1) status = "Слухаю..";
    if (_currentState == 2) status = "Аналізую макроси..";
    if (_currentState == 4) status = "Редагування..";
    if (_currentState == 5) status = "Перевірка..";
    if (_currentState == 6) status = "Збереження..";
    if (_currentState == 3) status = "Завершено.";

    return Text(
      status,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: 40, right: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Keyboard Button
          GestureDetector(
            onTap: () {
              if (_currentState == 0 || _currentState == 3) {
                _switchToEditMode("");
              }
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_alt_outlined,
                color: Colors.white70,
                size: 24,
              ),
            ),
          ),

          // Main Record Button
          GestureDetector(
            onLongPressDown: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecordingAndEdit(),
            onLongPressCancel: () => _stopRecordingAndEdit(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _currentState == 1 ? 80 : 70,
              height: _currentState == 1 ? 80 : 70,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
                boxShadow: _currentState == 1
                    ? [
                        BoxShadow(
                          color: AppColors.primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: const Icon(Icons.mic, color: Colors.black, size: 30),
            ),
          ),

          // Cancel/Delete Button
          GestureDetector(
            onTap: () {
              setState(() {
                _currentState = 0;
                _recognizedText = "";
                _finalResponse = "";
              });
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showRing =>
      _currentState == 0 || _currentState == 1 || _currentState == 3;
  bool get _showBottomControls =>
      _currentState == 0 || _currentState == 1 || _currentState == 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Subtle accent gradient at the bottom
          Positioned(
            bottom: -100,
            left: 0,
            right: 0,
            height: 400,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 1.5,
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopNavyBar(),

                // Info overlay dropdown
                _buildInfoOverlay(),

                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        if (_showRing) ...[
                          const SizedBox(height: 30),
                          _buildDottedRing(),
                          const SizedBox(height: 30),
                        ],

                        // Main Content (text/edit/review)
                        _buildMainText(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Status Text
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Center(child: _buildStatusText()),
                ),

                // Bottom Controls
                if (_showBottomControls)
                  _buildBottomControls()
                else
                  const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the intricately dotted ring
class DottedRingPainter extends CustomPainter {
  final bool isRecording;
  final double animationValue;

  DottedRingPainter({required this.isRecording, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Config for rings
    final int numRings = 8;
    final double innerRadius = size.width * 0.25;
    final double outerRadius = size.width * 0.45;

    for (int ringIndex = 0; ringIndex < numRings; ringIndex++) {
      double t = numRings == 1 ? 0 : ringIndex / (numRings - 1);
      double currentRadius = innerRadius + (outerRadius - innerRadius) * t;

      // Calculate number of dots for this ring based on circumference
      int numDots = (currentRadius * 2 * math.pi / 8).round();

      for (int i = 0; i < numDots; i++) {
        double angle = (2 * math.pi * i) / numDots;

        // Add some offset so dots don't line up perfectly radially
        double angleOffset = ringIndex * 0.1;

        double x = center.dx + currentRadius * math.cos(angle + angleOffset);
        double y = center.dy + currentRadius * math.sin(angle + angleOffset);

        // Calculate dot opacity and size based on position and animation
        double dotSize = 1.2;
        double opacity = 0.2; // Base opacity

        // Enhance opacity/size somewhat randomly across the structure to match reference
        double noise = math.sin(x * 0.1) * math.cos(y * 0.1);
        if (noise > 0.5) {
          opacity = 0.4;
          dotSize = 1.8;
        } else if (noise > 0.8) {
          opacity = 0.7;
          dotSize = 2.2;
        }

        if (isRecording) {
          // If recording, animate the intensities slightly
          double wave = math.sin(angle * 3 + animationValue * math.pi * 2);
          opacity = (opacity + wave * 0.3).clamp(0.1, 1.0);
          dotSize += wave * 0.5;
        }

        paint.color = Colors.white.withOpacity(opacity);
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DottedRingPainter oldDelegate) {
    return oldDelegate.isRecording != isRecording ||
        oldDelegate.animationValue != animationValue;
  }
}
