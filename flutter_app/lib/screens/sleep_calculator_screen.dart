import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/constants/app_colors.dart';
import 'package:intl/intl.dart';

class SleepCalculatorScreen extends StatefulWidget {
  const SleepCalculatorScreen({super.key});

  @override
  State<SleepCalculatorScreen> createState() => _SleepCalculatorScreenState();
}

class _SleepCalculatorScreenState extends State<SleepCalculatorScreen>
    with SingleTickerProviderStateMixin {
  DateTime _bedTime = DateTime.now();
  DateTime _wakeTime = DateTime.now().add(
    const Duration(hours: 7, minutes: 45),
  ); // Default ~5 cycles

  bool _isBedTimeNow = false;

  // Animation for entry
  late AnimationController _entryAnimController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryAnimController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryAnimController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Start entry animation immediately
    _entryAnimController.forward();

    _setBedTimeToNow(shouldSetState: false);
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  void _setBedTimeToNow({bool shouldSetState = true}) {
    void logic() {
      _isBedTimeNow = true;
      _bedTime = DateTime.now();
      // Auto-calculate optimal wake time (5 cycles = 7.5h + 15m fall asleep)
      // 5 cycles * 90m = 450m. + 15m = 465m.
      _wakeTime = _bedTime.add(const Duration(minutes: 465));
    }

    if (shouldSetState) {
      setState(logic);
    } else {
      logic();
    }
  }

  double _calculateCycles() {
    // Duration - 15 min fall asleep
    Duration sleepDuration = _wakeTime.difference(_bedTime);

    // Handle day wrap adjustment if wake time is "before" bed time in pure hour terms
    // But DateTime handles dates, so we need to ensure dates are correct.
    // For the UI picker, we pick TimeOfDay mostly.

    // Let's normalize dates.
    // If wake time is before bed time, add 1 day to wake time.
    if (_wakeTime.isBefore(_bedTime)) {
      // This implies next day
      // But wait, our state uses full DateTime?
      // If using CupertinoPicker in date mode, it sets full date.
      // If using time mode, it sets HH:MM.
    }

    // Just calculate minutes
    int totalMinutes = sleepDuration.inMinutes;
    // Handle wrap around if dates aren't perfectly synced (though we try to sync them)
    // If negative, it means next day (implicit)
    if (totalMinutes < 0) totalMinutes += 24 * 60;

    int actualSleepMinutes = totalMinutes - 15;
    if (actualSleepMinutes < 0) actualSleepMinutes = 0;

    return actualSleepMinutes / 90.0;
  }

  Color _getQualityColor(double cycles) {
    if (cycles < 3 || cycles > 7) {
      return Colors.orangeAccent; // Too little or too much
    }

    // Check how close to integer (x.0)
    double diff = (cycles - cycles.round()).abs();
    if (diff < 0.1) return AppColors.primaryColor; // Excellent timing
    if (diff < 0.2) return Colors.lightGreen; // Good timing
    return Colors.yellow; // Okay timing
  }

  String _getQualityText(double cycles) {
    int whole = cycles.round();
    double diff = (cycles - whole).abs();

    if (cycles < 4) {
      return "Замало сну (${(cycles * 1.5).toStringAsFixed(1)} год)";
    }
    if (cycles > 7) {
      return "Забагато сну (${(cycles * 1.5).toStringAsFixed(1)} год)";
    }

    if (diff < 0.15) {
      if (whole >= 5 && whole < 7) return "Чудово! (≈$whole циклів)";
      return "Хороший час (≈$whole циклів)";
    }
    if (diff < 0.3) return "Непогано (≈$whole циклів)";
    return "Можлива млявість (${(cycles * 1.5).toStringAsFixed(1)} год)";
  }

  @override
  Widget build(BuildContext context) {
    double cycles = _calculateCycles();
    Color statusColor = _getQualityColor(cycles);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            "Оберіть час пробудження",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildArcPicker(cycles, statusColor),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _getQualityText(cycles),
                              key: ValueKey(cycles.round()),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: statusColor.withOpacity(0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 50),
                          _buildBedTimeControls(),
                          const SizedBox(height: 40),
                          _buildInfoNote(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            "Калькулятор сну",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArcPicker(double cycles, Color statusColor) {
    // Calculate progress based on QUALITY not just quantity
    double progressValue = _calculateProgress(cycles);

    return Center(
      child: SizedBox(
        width: 320,
        height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Arc
            CustomPaint(
              size: const Size(320, 320),
              painter: ArcPainter(
                color: Colors.white.withOpacity(0.05),
                progress: 1.0,
                strokeWidth: 24,
              ),
            ),
            // Active Arc (Animated)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progressValue),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return CustomPaint(
                  size: const Size(320, 320),
                  painter: ArcPainter(
                    color: statusColor,
                    progress: value,
                    strokeWidth: 24,
                    glow: true,
                  ),
                );
              },
            ),

            // Picker Inside
            SizedBox(
              width: 200,
              height: 150,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24, // Large Text - Kept as requested
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: _wakeTime,
                  use24hFormat: true,
                  onDateTimeChanged: (val) {
                    setState(() {
                      _wakeTime = val;
                      // Ensure date consistencies if needed
                      if (_wakeTime.isBefore(_bedTime)) {
                        _wakeTime = _wakeTime.add(const Duration(days: 1));
                      }
                      // If diff > 24h, reduce day
                      if (_wakeTime.difference(_bedTime).inHours > 24) {
                        _wakeTime = _wakeTime.subtract(const Duration(days: 1));
                      }
                    });
                  },
                ),
              ),
            ),

            // Label top
            Positioned(
              top: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glassCardColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ), // Glass border
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Text(
                  "⏰ Встаю о",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateProgress(double cycles) {
    if (cycles < 3 || cycles > 7) {
      // Too little or too much -> reduced fill
      return 0.4;
    }

    int whole = cycles.round();
    double diff = (cycles - whole).abs();

    // "Чудово" (Excellent) -> Full fill
    if (diff < 0.15 && whole >= 5 && whole < 7) {
      return 1.0;
    }

    // "Хороший час" (Good time) -> High fill
    if (diff < 0.15) {
      return 0.95;
    }

    // "Непогано" (Not bad) -> Slightly less
    if (diff < 0.3) {
      return 0.85;
    }

    // "Можлива млявість" -> Reduced
    return 0.6;
  }

  Widget _buildBedTimeControls() {
    String bedTimeStr = DateFormat('HH:mm').format(_bedTime);

    // New Style for container and buttons
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor.withOpacity(0.05), // More subtle glass
        borderRadius: BorderRadius.circular(30), // More rounded
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nights_stay_rounded,
                  color: AppColors.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Лягаю спати:",
                style: TextStyle(
                  color: AppColors.textWhite.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _setBedTimeToNow,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _isBedTimeNow
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: _isBedTimeNow
                          ? null
                          : Border.all(
                              color: AppColors.textGrey.withOpacity(0.3),
                            ),
                    ),
                    child: Center(
                      child: Text(
                        "Зараз",
                        style: TextStyle(
                          color: _isBedTimeNow
                              ? Colors
                                    .black // Assuming primary is bright
                              : AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _isBedTimeNow = false);
                    _showBedTimePicker();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: !_isBedTimeNow
                          ? AppColors.cardColor.withOpacity(
                              0.5,
                            ) // Active card color or glass
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: !_isBedTimeNow
                          ? Border.all(
                              color: AppColors.primaryColor.withOpacity(0.5),
                            )
                          : Border.all(
                              color: AppColors.textGrey.withOpacity(0.3),
                            ),
                      boxShadow: !_isBedTimeNow
                          ? [
                              BoxShadow(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        _isBedTimeNow ? "Інший час" : bedTimeStr,
                        style: TextStyle(
                          color: !_isBedTimeNow
                              ? AppColors.textWhite
                              : AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
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

  void _showBedTimePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: _bedTime,
                  use24hFormat: true,
                  onDateTimeChanged: (val) {
                    setState(() {
                      _bedTime = val;
                      // Auto-adjust wake time to nearest optimal?
                      // Let's just update bed time and let user adjust wake time,
                      // OR snap wake time to maintain current cycle count?

                      // Maintaining cycle count is good UX
                      double currentCycles = _calculateCycles();
                      int targetCycles = currentCycles.round();
                      if (targetCycles < 3) targetCycles = 5;

                      int sleepMinutes = (targetCycles * 90) + 15;
                      _wakeTime = _bedTime.add(Duration(minutes: sleepMinutes));
                    });
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'Готово',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        "* Розрахунок включає 15 хвилин на засинання та цикли сну по 90 хвилин.",
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class ArcPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double strokeWidth;
  final bool glow;

  ArcPainter({
    required this.color,
    required this.progress,
    required this.strokeWidth,
    this.glow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (glow) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);
    }

    // Draw open circle (gap at bottom)
    const startAngle = pi * 0.8; // Start bottom left
    const sweepAngle = pi * 1.4; // Sweep to bottom right

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ArcPainter oldDelegate) {
    // Always repaint if glow to maintain effect or use properties
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
