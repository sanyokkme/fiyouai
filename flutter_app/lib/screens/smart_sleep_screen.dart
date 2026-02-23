import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class SmartSleepScreen extends StatefulWidget {
  const SmartSleepScreen({super.key});

  @override
  State<SmartSleepScreen> createState() => _SmartSleepScreenState();
}

class _SmartSleepScreenState extends State<SmartSleepScreen>
    with TickerProviderStateMixin {
  // ── Tab controller ──
  late TabController _tabController;

  // ── Entry animation ──
  late AnimationController _entryAnimController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ── Calculator state (from old screen) ──
  DateTime _bedTime = DateTime.now();
  DateTime _wakeTime = DateTime.now().add(
    const Duration(hours: 7, minutes: 45),
  );
  bool _isBedTimeNow = false;
  int _textKeyCounter = 0;
  String _currentQualityText = "";

  // ── Smart Sleep state (new) ──
  // Wake-up time is derived from the calculator tab's _wakeTime
  TimeOfDay get _smartWakeUpTime =>
      TimeOfDay(hour: _wakeTime.hour, minute: _wakeTime.minute);
  static const int _cycleDuration = 90;
  int _fallAsleepMinutes = 15;
  int _sleepQuality = 0;
  final List<String> _qualityEmojis = ['😴', '😐', '🙂', '😊', '🤩'];
  final List<String> _qualityLabels = [
    'Жахливо',
    'Погано',
    'Нормально',
    'Добре',
    'Чудово',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _entryAnimController.forward();
    _setBedTimeToNow(shouldSetState: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entryAnimController.dispose();
    super.dispose();
  }

  // ═══════════════════════  CALCULATOR LOGIC  ═══════════════════════
  void _setBedTimeToNow({bool shouldSetState = true}) {
    void logic() {
      _isBedTimeNow = true;
      _bedTime = DateTime.now();
      _wakeTime = _bedTime.add(const Duration(minutes: 465));
      _currentQualityText = _getQualityText(_calculateCycles());
      _textKeyCounter++;
    }

    if (shouldSetState) {
      setState(logic);
    } else {
      logic();
    }
  }

  double _calculateCycles() {
    int totalMinutes = _wakeTime.difference(_bedTime).inMinutes;
    if (totalMinutes < 0) totalMinutes += 24 * 60;
    int actualSleepMinutes = totalMinutes - 15;
    if (actualSleepMinutes < 0) actualSleepMinutes = 0;
    return actualSleepMinutes / 90.0;
  }

  Color _getQualityColor(double cycles) {
    if (cycles < 3 || cycles > 7) return Colors.orangeAccent;
    double diff = (cycles - cycles.round()).abs();
    if (diff < 0.1) return AppColors.primaryColor;
    if (diff < 0.2) return Colors.lightGreen;
    return Colors.yellow;
  }

  String _getQualityText(double cycles) {
    int whole = cycles.round();
    double diff = (cycles - whole).abs();
    if (cycles < 4)
      return "Замало сну (${(cycles * 1.5).toStringAsFixed(1)} год)";
    if (cycles > 7)
      return "Забагато сну (${(cycles * 1.5).toStringAsFixed(1)} год)";
    if (diff < 0.15) {
      if (whole >= 5 && whole < 7) return "Чудово! (≈$whole циклів)";
      return "Хороший час (≈$whole циклів)";
    }
    if (diff < 0.3) return "Непогано (≈$whole циклів)";
    return "Можлива млявість (${(cycles * 1.5).toStringAsFixed(1)} год)";
  }

  double _calculateProgress(double cycles) {
    if (cycles < 3 || cycles > 7) return 0.4;
    int whole = cycles.round();
    double diff = (cycles - whole).abs();
    if (diff < 0.15 && whole >= 5 && whole < 7) return 1.0;
    if (diff < 0.15) return 0.95;
    if (diff < 0.3) return 0.85;
    return 0.6;
  }

  // ═══════════════════════  SMART SLEEP LOGIC  ═══════════════════════
  List<TimeOfDay> _calculateBedtimes() {
    List<TimeOfDay> bedtimes = [];
    for (int cycles = 6; cycles >= 3; cycles--) {
      int totalMinutes = cycles * _cycleDuration + _fallAsleepMinutes;
      int wakeMinutes = _smartWakeUpTime.hour * 60 + _smartWakeUpTime.minute;
      int bedMinutes = wakeMinutes - totalMinutes;
      if (bedMinutes < 0) bedMinutes += 24 * 60;
      bedtimes.add(
        TimeOfDay(hour: (bedMinutes ~/ 60) % 24, minute: bedMinutes % 60),
      );
    }
    return bedtimes;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getSleepDuration(int cycles) {
    int total = cycles * _cycleDuration;
    int hours = total ~/ 60;
    int mins = total % 60;
    return mins > 0 ? '${hours}г ${mins}хв' : '${hours}г';
  }

  // ═══════════════════════  GLASS CARD  ═══════════════════════
  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    double borderRadius = 24,
    Color? glowColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════  BUILD  ═══════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 25, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Розумний сон",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.indigoAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.nightlight_round,
                            color: Colors.indigoAccent,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Smart',
                            style: TextStyle(
                              color: Colors.indigoAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tabs ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primaryColor,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    dividerHeight: 0,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, size: 16),
                            SizedBox(width: 6),
                            Text('Калькулятор'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bedtime, size: 16),
                            SizedBox(width: 6),
                            Text('Поради'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Tab content ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildCalculatorTab(), _buildSmartTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════  TAB 1: CALCULATOR  ═══════════════════════
  Widget _buildCalculatorTab() {
    double cycles = _calculateCycles();
    Color statusColor = _getQualityColor(cycles);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                  key: ValueKey('$_currentQualityText-$_textKeyCounter'),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),
              _buildBedTimeControls(),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "* Розрахунок включає 15 хвилин на засинання та цикли сну по 90 хвилин.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArcPicker(double cycles, Color statusColor) {
    double progressValue = _calculateProgress(cycles);
    return Center(
      child: SizedBox(
        width: 320,
        height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(320, 320),
              painter: ArcPainter(
                color: Colors.white.withValues(alpha: 0.05),
                progress: 1.0,
                strokeWidth: 24,
              ),
            ),
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
            SizedBox(
              width: 200,
              height: 150,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
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
                      if (_wakeTime.isBefore(_bedTime))
                        _wakeTime = _wakeTime.add(const Duration(days: 1));
                      if (_wakeTime.difference(_bedTime).inHours > 24)
                        _wakeTime = _wakeTime.subtract(const Duration(days: 1));
                      String newText = _getQualityText(_calculateCycles());
                      if (newText != _currentQualityText) {
                        _currentQualityText = newText;
                        _textKeyCounter++;
                      }
                    });
                  },
                ),
              ),
            ),
            Positioned(
              top: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glassCardColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Text(
                  "⏰ Встаю о",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBedTimeControls() {
    String bedTimeStr = DateFormat('HH:mm').format(_bedTime);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.2),
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
                  color: AppColors.textWhite.withValues(alpha: 0.9),
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
                              color: AppColors.textGrey.withValues(alpha: 0.3),
                            ),
                    ),
                    child: Center(
                      child: Text(
                        "Зараз",
                        style: TextStyle(
                          color: _isBedTimeNow
                              ? Colors.black
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
                  onTap: () {
                    setState(() => _isBedTimeNow = false);
                    _showBedTimePicker();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: !_isBedTimeNow
                          ? AppColors.cardColor.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: !_isBedTimeNow
                          ? Border.all(
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.5,
                              ),
                            )
                          : Border.all(
                              color: AppColors.textGrey.withValues(alpha: 0.3),
                            ),
                      boxShadow: !_isBedTimeNow
                          ? [
                              BoxShadow(
                                color: AppColors.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
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
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      fontWeight: FontWeight.bold,
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
                      double currentCycles = _calculateCycles();
                      int targetCycles = currentCycles.round();
                      if (targetCycles < 3) targetCycles = 5;
                      _wakeTime = _bedTime.add(
                        Duration(minutes: (targetCycles * 90) + 15),
                      );
                      String newText = _getQualityText(_calculateCycles());
                      if (newText != _currentQualityText) {
                        _currentQualityText = newText;
                        _textKeyCounter++;
                      }
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

  // ═══════════════════════  TAB 2: SMART SLEEP  ═══════════════════════
  Widget _buildSmartTab() {
    final bedtimes = _calculateBedtimes();
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildWakeUpPicker(),
          const SizedBox(height: 16),
          _buildFallAsleepSlider(),
          const SizedBox(height: 24),
          _buildBedtimeRecommendations(bedtimes),
          const SizedBox(height: 24),
          _buildSleepQualityTracker(),
          const SizedBox(height: 24),
          _buildSleepTips(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildWakeUpPicker() {
    return _glassCard(
      glowColor: Colors.indigoAccent,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.indigoAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigoAccent.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.alarm,
              color: Colors.indigoAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Час підйому (з калькулятора)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatTime(_smartWakeUpTime),
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigoAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '🔗 Синхр.',
              style: TextStyle(
                color: Colors.indigoAccent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallAsleepSlider() {
    return _glassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_bottom,
                color: Colors.purpleAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Час засинання',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_fallAsleepMinutes хв',
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.purpleAccent,
              inactiveTrackColor: Colors.purpleAccent.withValues(alpha: 0.15),
              thumbColor: Colors.purpleAccent,
              overlayColor: Colors.purpleAccent.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _fallAsleepMinutes.toDouble(),
              min: 5,
              max: 45,
              divisions: 8,
              onChanged: (v) => setState(() => _fallAsleepMinutes = v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBedtimeRecommendations(List<TimeOfDay> bedtimes) {
    final cycleLabels = ['6 циклів', '5 циклів', '4 цикли', '3 цикли'];
    final cycleColors = [
      Colors.greenAccent,
      Colors.tealAccent,
      Colors.amberAccent,
      Colors.orangeAccent,
    ];
    final recommendations = [
      'Ідеально! 💚',
      'Рекомендовано 👍',
      'Мінімум ⚠️',
      'Мало сну ❌',
    ];
    final cycleCounts = [6, 5, 4, 3];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.indigoAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Рекомендований час сну',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(
          bedtimes.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _glassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 18,
              glowColor: i == 0 ? cycleColors[i] : null,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cycleColors[i].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.bedtime, color: cycleColors[i], size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTime(bedtimes[i]),
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${cycleLabels[i]} · ${_getSleepDuration(cycleCounts[i])}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cycleColors[i].withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      recommendations[i],
                      style: TextStyle(
                        color: cycleColors[i],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSleepQualityTracker() {
    return _glassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_outline,
                color: Colors.amberAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Як ви спали сьогодні?',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(5, (i) {
              bool selected = _sleepQuality == i + 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _sleepQuality = i + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.amberAccent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? Colors.amberAccent.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.06),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _qualityEmojis[i],
                            style: TextStyle(fontSize: selected ? 24 : 20),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _qualityLabels[i],
                            style: TextStyle(
                              color: selected
                                  ? Colors.amberAccent
                                  : AppColors.textSecondary,
                              fontSize: 9,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTips() {
    final tips = [
      {
        'icon': Icons.phone_android,
        'text': 'Уникайте екранів за 30 хвилин до сну',
        'color': Colors.blueAccent,
      },
      {
        'icon': Icons.local_cafe,
        'text': 'Останній кофе — за 6 годин до сну',
        'color': Colors.brown,
      },
      {
        'icon': Icons.thermostat,
        'text': 'Оптимальна температура в кімнаті: 18-20°C',
        'color': Colors.tealAccent,
      },
      {
        'icon': Icons.self_improvement,
        'text': 'Спробуйте медитацію або дихальні вправи',
        'color': Colors.purpleAccent,
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.indigoAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Поради для кращого сну',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _glassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (tip['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      tip['icon'] as IconData,
                      color: tip['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip['text'] as String,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════  ARC PAINTER  ═══════════════════════
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
    if (glow) paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);
    const startAngle = pi * 0.8;
    const sweepAngle = pi * 1.4;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ArcPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
