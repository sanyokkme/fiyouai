import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';

class WaterDetailsScreen extends StatefulWidget {
  final int currentWater;
  final int targetWater;
  final void Function(int amount) onAddWater;
  final Map<String, dynamic> historyData;

  const WaterDetailsScreen({
    super.key,
    required this.currentWater,
    required this.targetWater,
    required this.onAddWater,
    required this.historyData,
  });

  @override
  State<WaterDetailsScreen> createState() => _WaterDetailsScreenState();
}

class _WaterDetailsScreenState extends State<WaterDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late int _localCurrentWater;

  // Background animated blob controllers
  late AnimationController _blob1Controller;
  late AnimationController _blob2Controller;
  late AnimationController _blob3Controller;

  @override
  void initState() {
    super.initState();
    _localCurrentWater = widget.currentWater;
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _blob1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _blob2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _blob3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _blob1Controller.dispose();
    _blob2Controller.dispose();
    _blob3Controller.dispose();
    super.dispose();
  }

  String _getMotivationText(int percentage) {
    if (percentage == 0) return "Давайте почнемо день з води!";
    if (percentage < 30) return "Чудовий початок! Продовжуйте.";
    if (percentage < 60) return "Вже майже половина! Ви молодець.";
    if (percentage < 100) return "Ще трохи до мети!";
    return "Мета досягнута! Супер!";
  }

  @override
  Widget build(BuildContext context) {
    double progress =
        (widget.targetWater > 0 ? _localCurrentWater / widget.targetWater : 0.0)
            .clamp(0.0, 1.0);
    int percentage = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background blur spots matching theme
          _buildBackgroundWithBlurSpots(),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildWaterProgressRing(progress, percentage),
                        const SizedBox(height: 32),
                        _buildWeeklyWaterChart(),
                        const SizedBox(height: 32),

                        // "Why Water?" or benefits section
                        SlideFadeIn(
                          delayMs: 150,
                          child: _buildSectionTitle(
                            "Користь води для організму",
                          ),
                        ),
                        const SizedBox(height: 24),
                        SlideFadeIn(
                          delayMs: 300,
                          child: _buildBenefitCard(
                            icon: Icons.lightbulb_outline_rounded,
                            title: "Енергія та фокус",
                            description:
                                "Навіть легке зневоднення може спричинити втому та знизити концентрацію уваги. Підтримуйте водний баланс для продуктивності протягом дня.",
                            color: const Color(0xFFFFD166),
                          ),
                        ),
                        SlideFadeIn(
                          delayMs: 450,
                          child: _buildBenefitCard(
                            icon: Icons.monitor_weight_outlined,
                            title: "Контроль ваги",
                            description:
                                "Вода допомагає прискорити метаболізм. Іноді організм плутає спрагу з голодом, тому вода може допомогти уникнути зайвих перекусів.",
                            color: const Color(0xFF06D6A0),
                          ),
                        ),
                        SlideFadeIn(
                          delayMs: 600,
                          child: _buildBenefitCard(
                            icon: Icons.spa_outlined,
                            title: "Здорова шкіра",
                            description:
                                "Достатнє споживання води зберігає шкіру зволоженою. Вона виглядає більш пружною, сяючою та здоровою.",
                            color: const Color(0xFF118AB2),
                          ),
                        ),
                        SlideFadeIn(
                          delayMs: 750,
                          child: _buildBenefitCard(
                            icon: Icons.health_and_safety_outlined,
                            title: "Очищення організму",
                            description:
                                "Вода допомагає ниркам ефективно виводити токсини з організму та зменшує ризик утворення каменів.",
                            color: const Color(0xFFEF476F),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 16,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: const Text(
        "Гідратація",
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      pinned: true,
    );
  }

  Widget _buildWaterProgressRing(double progress, int percentage) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.glassCardColor,
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.2),
          width: 8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Wave animation background mask
          ClipOval(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 2000),
                  curve: Curves.easeOutCubic,
                  builder: (context, fillHeight, child) {
                    return CustomPaint(
                      size: const Size(280, 280),
                      painter: _WaterProgressPainter(
                        fillHeight: fillHeight,
                        wavePhase: _waveController.value,
                        color: Colors.blueAccent.withValues(alpha: 0.6),
                        backgroundColor: Colors.blueAccent.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Progress text in the center
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: _localCurrentWater),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Text(
                    "$value / ${widget.targetWater}",
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                "мілілітрів ($percentage%)",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getMotivationText(percentage),
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    const days = ['Пн', 'Вв', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    return days[date.weekday - 1];
  }

  Widget _buildWeeklyWaterChart() {
    // Determine the last 7 days
    List<Map<String, dynamic>> weeklyData = [];
    DateTime now = DateTime.now();
    double maxWater = 2000;

    for (int i = 6; i >= 0; i--) {
      DateTime date = now.subtract(Duration(days: i));
      String dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      int water = 0;
      int target = widget.targetWater > 0 ? widget.targetWater : 2000;

      if (i == 0) {
        water = _localCurrentWater;
      } else if (widget.historyData.containsKey(dateStr)) {
        final dayData = widget.historyData[dateStr];
        water = (dayData['water'] ?? 0).toInt();
        target = (dayData['water_target'] ?? target).toInt();
      }

      if (water > maxWater) maxWater = water.toDouble();
      if (target > maxWater) maxWater = target.toDouble();

      weeklyData.add({
        'date': date,
        'water': water.toDouble(),
        'target': target.toDouble(),
      });
    }

    maxWater += 500; // Add some padding to the top of the chart

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Статистика за 7 днів",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxWater,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < weeklyData.length) {
                          DateTime date = weeklyData[index]['date'];
                          bool isToday = index == 6;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _getDayName(date),
                              style: TextStyle(
                                color: isToday ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()} мл',
                        const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: List.generate(weeklyData.length, (index) {
                  final data = weeklyData[index];
                  final double water = data['water'];
                  final double target = data['target'];

                  double cutoff = target > 0 ? (target / water) : 1.0;
                  if (cutoff > 1.0) cutoff = 1.0;
                  if (water == 0) cutoff = 1.0;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: water,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueAccent,
                            Colors.blueAccent,
                            Colors.indigo,
                          ],
                          stops: [0.0, cutoff, 1.0],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxWater,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundWithBlurSpots() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _blob1Controller,
        _blob2Controller,
        _blob3Controller,
      ]),
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.backgroundDark,
          child: Stack(
            children: [
              // Blob 1
              Positioned(
                left: -100 + (200 * _blob1Controller.value),
                top:
                    100 +
                    (100 * math.sin(_blob1Controller.value * math.pi * 2)),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2C7DA0).withValues(alpha: 0.15),
                        const Color(0xFF2C7DA0).withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Blob 2
              Positioned(
                right: -50 + (150 * _blob2Controller.value),
                top:
                    250 + (80 * math.cos(_blob2Controller.value * math.pi * 2)),
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4361EE).withValues(alpha: 0.15),
                        const Color(0xFF4361EE).withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Blob 3
              Positioned(
                left:
                    MediaQuery.of(context).size.width * 0.3 +
                    (100 * _blob3Controller.value),
                bottom:
                    100 +
                    (120 * math.sin(_blob3Controller.value * math.pi * 3)),
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryColor.withValues(alpha: 0.15),
                        AppColors.primaryColor.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Animated overlay to slightly soften the effect
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundDark.withValues(alpha: 0.2),
                      AppColors.backgroundDark.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaterProgressPainter extends CustomPainter {
  final double fillHeight;
  final double wavePhase;
  final Color color;
  final Color backgroundColor;

  _WaterProgressPainter({
    required this.fillHeight,
    required this.wavePhase,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // We already imported math at the top in previous steps, but since it's missing, let's just use it properly.
    // Assuming dart:math is imported at the top of the file.
    final double width = size.width;
    final double height = size.height;

    // Draw background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawCircle(Offset(width / 2, height / 2), width / 2, bgPaint);

    if (fillHeight == 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final waterHeight = height * (1 - fillHeight);
    final waveAmplitude = 10.0;

    final path = Path();
    path.moveTo(0, waterHeight);

    for (double i = 0; i <= width; i++) {
      // sine wave combining two frequencies for natural look.
      double waveY =
          waterHeight +
          (waveAmplitude * 0.7) *
              (1 - fillHeight < 0.95 ? 1 : 0.2) *
              math.sin((i / width * math.pi * 2) + (wavePhase * math.pi * 2));

      double secondWaveY =
          waterHeight +
          (waveAmplitude * 0.4) *
              (1 - fillHeight < 0.95 ? 1 : 0.2) *
              math.sin((i / width * math.pi * 4) - (wavePhase * math.pi * 1.5));

      // Average coordinates for the drawing point
      double finalY = (waveY + secondWaveY) / 2;
      path.lineTo(i, finalY);
    }

    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    // Mask to circle
    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, width, height)));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaterProgressPainter oldDelegate) {
    return oldDelegate.fillHeight != fillHeight ||
        oldDelegate.wavePhase != wavePhase;
  }
}

class SlideFadeIn extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const SlideFadeIn({super.key, required this.child, required this.delayMs});

  @override
  State<SlideFadeIn> createState() => _SlideFadeInState();
}

class _SlideFadeInState extends State<SlideFadeIn> {
  bool _start = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        setState(() {
          _start = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: _start ? 1.0 : 0.0,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 800),
        offset: _start ? Offset.zero : const Offset(0, 0.15),
        curve: Curves.easeOutQuart,
        child: widget.child,
      ),
    );
  }
}
