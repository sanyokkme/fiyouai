// Обовязкові імпорти
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

// Імпорти сервісів
import 'package:flutter_app/services/data_manager.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/services/notification_service.dart';

// Імпорти констант
import 'package:flutter_app/constants/app_colors.dart';
import 'package:flutter_app/services/home_layout_service.dart';
import 'package:fl_chart/fl_chart.dart'; // Add fl_chart import

// Імпорти віджетів
import 'package:flutter_app/widgets/weight_update_sheet.dart';
import 'package:animations/animations.dart';

// Імпорти екранів
// import 'package:flutter_app/screens/story_view_screen.dart'; // Unused
import 'package:flutter_app/screens/all_vitamins_screen.dart';
import 'package:flutter_app/screens/smart_sleep_screen.dart';
import 'package:flutter_app/screens/weight_tracker_screen.dart';
import 'package:flutter_app/screens/day_stats_screen.dart';
import 'package:flutter_app/screens/pdf_template_screen.dart';
import 'package:flutter_app/screens/about_screen.dart';
import 'package:flutter_app/screens/basic/water_details_screen.dart';

// Глобальна змінна для перевірки запуску конфетті
bool hasPlayedConfettiGlobal = false;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Map<String, dynamic>? _status;
  List<dynamic> _vitamins = [];
  bool _isLoading = true;
  late ConfettiController _confettiController;
  late PageController _pageController;
  String _greetingText = "Привіт!";

  // Стан тижневого календаря
  DateTime _selectedDate = DateTime.now();
  final Map<String, dynamic> _historyData = {};

  Timer? _pollingTimer;
  bool _isFirstNetworkLoad = true;

  // Анімація переходу дня
  late AnimationController _dayAnimController;
  late CurvedAnimation _dayAnimation;

  // Анімація хвилі
  late AnimationController _waveController;

  // Змінні для відображення даних
  double _displayEaten = 0;
  double _displayProtein = 0;
  double _displayFat = 0;
  double _displayCarbs = 0;
  double _displayWater = 0;
  double _fromEaten = 0,
      _fromProtein = 0,
      _fromFat = 0,
      _fromCarbs = 0,
      _fromWater = 0;
  double _toEaten = 0, _toProtein = 0, _toFat = 0, _toCarbs = 0, _toWater = 0;
  bool _displayValuesInitialized = false;

  // ── Mood Tracker ────────────────────────────────────────────────────
  int? _selectedMood; // 0-4 index
  static const List<Map<String, dynamic>> _moods = [
    {'emoji': '😫', 'label': 'Жахливо', 'color': Color(0xFFEF5350)},
    {'emoji': '😕', 'label': 'Погано', 'color': Color(0xFFFF7043)},
    {'emoji': '😐', 'label': 'Нормально', 'color': Color(0xFFFFCA28)},
    {'emoji': '😊', 'label': 'Добре', 'color': Color(0xFF66BB6A)},
    {'emoji': '🔥', 'label': 'Чудово', 'color': Color(0xFF42A5F5)},
  ];

  // ── Activity Timeline ───────────────────────────────────────────────
  List<Map<String, dynamic>> _activityTimeline = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Контролер конфетті
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Контролер сторінок
    _pageController = PageController(viewportFraction: 0.32);

    // Анімація + контролер переходу дня
    _dayAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dayAnimation = CurvedAnimation(
      parent: _dayAnimController,
      curve: Curves.easeOutCubic,
    );

    // Слухач анімації переходу дня
    _dayAnimController.addListener(() {
      final t = _dayAnimation.value;
      setState(() {
        _displayEaten = _fromEaten + (_toEaten - _fromEaten) * t;
        _displayProtein = _fromProtein + (_toProtein - _fromProtein) * t;
        _displayFat = _fromFat + (_toFat - _fromFat) * t;
        _displayCarbs = _fromCarbs + (_toCarbs - _fromCarbs) * t;
        _displayWater = _fromWater + (_toWater - _fromWater) * t;
      });
    });

    // Анімація + контролер хвилі
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _requestNotificationPermissions();
    DataManager().prefetchAllData();
    _fetchStatus();
    _fetchHistory();
    _fetchVitamins();
    _loadWeightHistory(); // Load weight history for graph
    _loadMood(); // Load saved mood for today
    _checkAndShowDailyWeightDialog();

    // Таймер для періодичного оновлення даних
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _fetchStatus(isPolling: true);
      _fetchVitamins();
    });
  }

  List<FlSpot> _weightHistory = [];

  Future<void> _loadWeightHistory() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    final jsonStr = await DataManager().getCachedWeightHistory(userId);
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr);
        if (data['history'] != null) {
          final List<dynamic> history = data['history'];
          // Sort by created_at (Oldest first) for the graph
          history.sort((a, b) {
            String dateA = a['created_at'] ?? a['date'] ?? '';
            String dateB = b['created_at'] ?? b['date'] ?? '';
            return dateA.compareTo(dateB);
          });

          final List<FlSpot> spots = [];
          for (int i = 0; i < history.length; i++) {
            // Use index as X
            final w = double.tryParse(history[i]['weight'].toString()) ?? 0;
            if (w > 0) {
              spots.add(FlSpot(i.toDouble(), w));
            }
          }
          if (mounted) {
            setState(() {
              _weightHistory = spots;
            });
          }
        }
      } catch (e) {
        debugPrint("Error loading weight history for graph: $e");
      }
    }
  }

  // Запит дозволів на сповіщення
  Future<void> _requestNotificationPermissions() async {
    await NotificationService().requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _dayAnimController.dispose();
    _waveController.dispose();
    _confettiController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchStatus();
      _fetchVitamins();
    }
  }

  // Оновлення привітання
  void _updateGreeting(String? name) {
    String displayName = "Друже";
    if (name != null && name.trim().isNotEmpty) {
      String trimmed = name.trim();
      displayName = trimmed.length > 1
          ? trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase()
          : trimmed.toUpperCase();
    }

    if (_greetingText.contains(displayName) && _greetingText != "Привіт!") {
      return;
    }

    // Список привітань
    final List<String> greetings = [
      "Привіт, $displayName!",
      "Вітаю, $displayName!",
      "Як успіхи, $displayName?",
      "Гарного дня, $displayName!",
    ];
    if (mounted) {
      setState(
        () => _greetingText = greetings[Random().nextInt(greetings.length)],
      );
    }
  }

  // Отримання даних про статус користувача
  Future<void> _fetchStatus({bool isPolling = false}) async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    if (!isPolling) {
      String? cachedData = DataManager().getCachedDataSync(
        'cached_status_$userId',
      );
      if (cachedData != null && _status == null) {
        if (mounted) {
          setState(() {
            _status = jsonDecode(cachedData);
            _isLoading = false;
          });
          _updateGreeting(_status!['name'] ?? _status!['username']);
          _rebuildTimeline(_status!);
        }
      }
    }

    // Попереднє завантаження даних
    DataManager().prefetchAllData();
    try {
      final res = await AuthService.authGet('/user_status/$userId');
      if (res.statusCode == 200) {
        final newData = jsonDecode(res.body);
        if (mounted && _status != null && !_isFirstNetworkLoad) {
          _checkForRemoteChanges(_status!, newData);
        }
        await DataManager().saveCachedData('cached_status_$userId', res.body);
        if (mounted) {
          bool wasFirstLoad = _isFirstNetworkLoad;
          setState(() {
            _status = newData;
            _isLoading = false;
            _isFirstNetworkLoad = false;
          });
          _loadWeightHistory(); // Refresh weight history when new data comes
          _rebuildTimeline(newData); // Rebuild activity timeline
          _updateGreeting(newData['name'] ?? newData['username']);
          bool waterMet =
              (newData['water'] ?? 0) >= (newData['water_target'] ?? 2000);
          bool foodMet =
              ((newData['eaten'] ?? 0) >= (newData['target'] ?? 2000)) &&
              ((newData['eaten'] ?? 0) > 0);
          // Конфетті грає лише якщо це НЕ перший завантаження, мета досягнута, і ще не грала в цій сесії
          if (!wasFirstLoad &&
              (waterMet || foodMet) &&
              !hasPlayedConfettiGlobal) {
            _confettiController.play();
            hasPlayedConfettiGlobal = true;
          }
        }
      }
    } catch (e) {
      if (mounted && _status == null) setState(() => _isLoading = false);
    }
  }

  // Отримання даних про вітаміни
  Future<void> _fetchVitamins() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;
    try {
      final res = await AuthService.authGet('/vitamins/$userId');
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _vitamins = jsonDecode(res.body);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching vitamins: $e");
    }
  }

  // Видалення вітаміну
  Future<void> _deleteVitamin(String id) async {
    try {
      final res = await AuthService.authDelete('/vitamins/$id');
      if (res.statusCode == 200) {
        _showSuccessNotification("Вітамін видалено 🗑️");
        _fetchVitamins();
      }
    } catch (e) {
      debugPrint("Error deleting vitamin: $e");
    }
  }

  // Перевірка змін даних
  void _checkForRemoteChanges(
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData,
  ) {
    double oldW = double.tryParse(oldData['weight']?.toString() ?? "0") ?? 0;
    double newW = double.tryParse(newData['weight']?.toString() ?? "0") ?? 0;

    if ((oldW - newW).abs() > 0.05) {
      NotificationService().showInstantNotification(
        "Дані оновлено 📲",
        "Ваша вага змінилась: $newW кг",
      );
    }
  }

  // Показ сповіщення про успіх
  void _showSuccessNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.black,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Додавання води
  Future<void> addWater([int amount = 250]) async {
    try {
      final userId = await AuthService.getStoredUserId();
      final String timestamp = DateTime.now().toIso8601String();
      if (_status != null) {
        setState(() => _status!['water'] = (_status!['water'] ?? 0) + amount);
      }

      final res = await AuthService.authPost('/add_water', {
        "user_id": userId,
        "amount": amount,
        "created_at": timestamp,
      });
      if (res.statusCode == 200) {
        _fetchStatus();
        _updateLocalCacheWithWater(amount);
      }
    } catch (e) {
      debugPrint("Water Error: $e");
    }
  }

  Future<void> _updateLocalCacheWithWater(int amount) async {
    try {
      final userId = await AuthService.getStoredUserId();
      if (userId == null) return;

      final box = Hive.box('offlineDataBox');
      final String cacheKey = 'cached_analytics_history_$userId';
      final String? cachedStr = box.get(cacheKey) as String?;

      List history = [];
      if (cachedStr != null) {
        history = jsonDecode(cachedStr);
      }

      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      bool found = false;

      for (var item in history) {
        if (item['day'] == today) {
          item['water'] = (item['water'] ?? 0) + amount;
          found = true;
          break;
        }
      }

      if (!found) {
        history.add({
          'day': today,
          'water': amount,
          'calories': 0,
          'protein': 0.0,
          'fat': 0.0,
          'carbs': 0.0,
        });
      }

      await box.put(cacheKey, jsonEncode(history));
      debugPrint("📦 Hive: Оновлено кеш історії (вода + $amount)");
    } catch (e) {
      debugPrint("⚠️ Hive Cache Update Error: $e");
    }
  }

  // Отримання історії
  Future<void> _fetchHistory() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;
    try {
      final res = await AuthService.authGet('/analytics/$userId');

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final Map<String, dynamic> historyMap = {};

        for (var item in data) {
          if (item['day'] != null) {
            historyMap[item['day']] = item;
          }
        }

        if (mounted) {
          setState(() {
            _historyData.addAll(historyMap);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    }
  }

  // Поточні дані
  Map<String, dynamic> get _currentData {
    if (isSameDay(_selectedDate, DateTime.now())) {
      return _status ?? {};
    }

    String dateKey = _selectedDate.toIso8601String().split('T')[0];
    if (_historyData.containsKey(dateKey)) {
      final hist = _historyData[dateKey];
      return {
        'eaten': hist['calories'] ?? 0,
        'target': _status?['target'] ?? 2000,
        'water': hist['water'] ?? 0,
        'water_target': _status?['water_target'] ?? 2000,
        'protein': (hist['protein'] ?? 0).toInt(),
        'fat': (hist['fat'] ?? 0).toInt(),
        'carbs': (hist['carbs'] ?? 0).toInt(),
        'target_p': _status?['target_p'] ?? 150,
        'target_f': _status?['target_f'] ?? 70,
        'target_c': _status?['target_c'] ?? 250,
        'goal': _status?['goal'] ?? 'maintain',
      };
    }

    return {
      'eaten': 0,
      'target': _status?['target'] ?? 2000,
      'water': 0,
      'water_target': _status?['water_target'] ?? 2000,
      'protein': 0,
      'fat': 0,
      'carbs': 0,
      'target_p': _status?['target_p'] ?? 150,
      'target_f': _status?['target_f'] ?? 70,
      'target_c': _status?['target_c'] ?? 250,
      'goal': _status?['goal'] ?? 'maintain',
    };
  }

  // Перевірка дат
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ── GLASSMORPHIC CONTAINER ──────────────────────────────────────────
  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 24,
    Color? glowColor,
    double blurSigma = 15,
  }) {
    return Container(
      margin: margin,
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
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
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

  Color _getTimeBasedTint() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return Colors.orange.withValues(alpha: 0.02); // Morning warm
    } else if (hour >= 11 && hour < 17) {
      return Colors.transparent; // Day
    } else if (hour >= 17 && hour < 21) {
      return Colors.deepPurple.withValues(alpha: 0.02); // Evening
    } else {
      return const Color(0xFF0D1B2A).withValues(alpha: 0.05); // Night
    }
  }

  List<Widget> _buildHomeWidgets(Map<String, dynamic> currentData) {
    List<Widget> renderedWidgets = [];
    final order = List<String>.from(HomeLayoutService().orderNotifier.value);
    for (String key in order) {
      switch (key) {
        case 'dashboard_stats':
          renderedWidgets.add(_buildDashboardStats(currentData));
          break;
        case 'mood_tracker':
          renderedWidgets.add(_buildMoodTracker());
          break;
        case 'water_tracker':
          renderedWidgets.add(
            _buildWaterTracker(
              _dayAnimController.isAnimating
                  ? _displayWater.round()
                  : currentData['water'] ?? 0,
              currentData['water_target'] ?? 2000,
            ),
          );
          break;
        case 'sleep_calculator':
          renderedWidgets.add(_buildSleepCalculatorCard());
          break;
        case 'vitamins_section':
          renderedWidgets.add(_buildVitaminsSection());
          break;
        case 'activity_timeline':
          renderedWidgets.add(_buildActivityTimeline());
          break;
      }
      renderedWidgets.add(const SizedBox(height: 24));
    }
    return renderedWidgets;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _status == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: AppColors.buildBackgroundWithBlurSpots(
          child: SafeArea(child: _buildSkeletonLoader()),
        ),
      );
    }

    final currentData = _currentData;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: AnimatedContainer(
          duration: const Duration(seconds: 3),
          color: _getTimeBasedTint(),
          child: Stack(
            children: [
              SafeArea(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        await _fetchStatus();
                        await _fetchHistory();
                        await _fetchVitamins();
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                              child: _buildHeader(),
                            ),
                            const SizedBox(height: 16),
                            _buildWeeklyCalendar(),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ValueListenableBuilder<List<String>>(
                                    valueListenable:
                                        HomeLayoutService().orderNotifier,
                                    builder: (context, _, child) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ..._buildHomeWidgets(currentData),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayIndicator(DateTime date, bool isTomorrow) {
    if (isTomorrow) {
      return CustomPaint(
        painter: DottedCirclePainter(
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Center(
          child: Text(
            date.day.toString(),
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    bool isToday = isSameDay(date, DateTime.now());
    int eaten = 0;
    int target = 2000;

    if (isToday) {
      eaten = _status?['eaten'] ?? 0;
      target = _status?['target'] ?? 2000;
    } else {
      String dKey = date.toIso8601String().split('T')[0];
      final hData = _historyData[dKey];
      if (hData != null) {
        eaten = (hData['calories'] ?? hData['eaten'] ?? 0).toInt();
        target = (hData['target'] ?? _status?['target'] ?? 2000).toInt();
      }
    }

    bool completed = eaten >= target && eaten > 0;
    bool started = eaten > 0 && eaten < target;

    Color? glowColor;
    Color dotColor = Colors.white.withValues(alpha: 0.3);

    if (completed) {
      dotColor = AppColors.primaryColor;
      glowColor = AppColors.primaryColor.withValues(alpha: 0.5);
    } else if (started) {
      dotColor = Colors.orangeAccent;
      glowColor = Colors.orangeAccent.withValues(alpha: 0.5);
    }

    return CustomPaint(
      painter: DottedCirclePainter(color: dotColor, glowColor: glowColor),
      child: Center(
        child: Text(
          date.day.toString(),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyCalendar() {
    final now = DateTime.now();

    // Only 6 real dates (5 days ago → today); 7th slot = calendar button
    final dates = List.generate(6, (i) => now.subtract(Duration(days: 5 - i)));

    int selectedIndex = dates.indexWhere((d) => isSameDay(d, _selectedDate));
    // selectedIndex == -1 means user picked a date via the full calendar
    // We still highlight today (index 5) as the active white dot when no week-date selected
    final int visibleSelected = selectedIndex; // may be -1

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OpenContainer(
        transitionDuration: const Duration(milliseconds: 400),
        transitionType: ContainerTransitionType.fadeThrough,
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: Colors.black.withValues(alpha: 0.6),
        middleColor: Colors.transparent,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        openBuilder: (context, action) {
          return _buildFullCalendarWidget(context, action);
        },
        closedBuilder: (context, action) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 88,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slotWidth = constraints.maxWidth / 7;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: [
                            // ── 6 real day slots ──────────────────────────────
                            ...List.generate(6, (index) {
                              final date = dates[index];
                              final isSelected = index == visibleSelected;

                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _animateToDay(date),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _getDayLetter(date),
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          opacity: isSelected ? 0.0 : 1.0,
                                          child: _buildDayIndicator(
                                            date,
                                            false,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            // ── 7th slot: calendar button ─────────────────────
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: action,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Всі',
                                      style: TextStyle(
                                        color: AppColors.primaryColor
                                            .withValues(alpha: 0.85),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryColor
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.primaryColor
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.calendar_month_rounded,
                                        color: AppColors.primaryColor,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ── Sliding white dot for selected day ────────────────
                        if (visibleSelected >= 0)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            left:
                                visibleSelected * slotWidth +
                                (slotWidth - 36) / 2,
                            top: 0,
                            bottom: 0,
                            width: 36,
                            child: IgnorePointer(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 14),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryColor
                                              .withValues(alpha: 0.35),
                                          blurRadius: 14,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        dates[visibleSelected].day.toString(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Full calendar view ────────────────────────────────────────────

  Widget _buildFullCalendarWidget(
    BuildContext context,
    VoidCallback closeContainer,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Start page = current month; allow scrolling back 24 months
    const int totalMonths = 25; // 0..24 → 24 months ago → today
    final int initialPage = totalMonths - 1;

    final PageController pageCtrl = PageController(initialPage: initialPage);

    // Selection state: single date or range
    bool rangeMode = false;
    DateTime? singleSelected = _selectedDate;
    DateTime? rangeStart;
    DateTime? rangeEnd;

    // For the animated month label
    int currentPageIndex = initialPage;

    DateTime monthFromPage(int page) {
      final monthsAgo = totalMonths - 1 - page;
      return DateTime(today.year, today.month - monthsAgo, 1);
    }

    // ── Helper: CSV export ────────────────────────────────────────────────
    void exportCSV(DateTime from, DateTime to) async {
      final buf = StringBuffer();
      buf.writeln('Дата,Калорії,Ціль,Білки(г),Жири(г),Вуглев.(г),Вода(мл)');

      DateTime cur = DateTime(from.year, from.month, from.day);
      final end = DateTime(to.year, to.month, to.day);
      while (!cur.isAfter(end)) {
        final dKey = cur.toIso8601String().split('T')[0];
        if (isSameDay(cur, today)) {
          buf.writeln(
            [
              dKey,
              _status?['eaten'] ?? 0,
              _status?['target'] ?? 2000,
              _status?['protein'] ?? 0,
              _status?['fat'] ?? 0,
              _status?['carbs'] ?? 0,
              _status?['water'] ?? 0,
            ].join(','),
          );
        } else if (_historyData.containsKey(dKey)) {
          final h = _historyData[dKey];
          buf.writeln(
            [
              dKey,
              h['calories'] ?? 0,
              _status?['target'] ?? 2000,
              (h['protein'] ?? 0).toInt(),
              (h['fat'] ?? 0).toInt(),
              (h['carbs'] ?? 0).toInt(),
              h['water'] ?? 0,
            ].join(','),
          );
        }
        cur = cur.add(const Duration(days: 1));
      }

      final String csv = buf.toString();
      // Save to temp file so share_plus can attach it
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/fiyou_export_${from.toIso8601String().split('T')[0]}_${to.toIso8601String().split('T')[0]}.csv',
      );
      await file.writeAsString(csv);

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv')],
          subject:
              'FiYou AI — дані за ${from.toIso8601String().split('T')[0]} – ${to.toIso8601String().split('T')[0]}',
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: StatefulBuilder(
          builder: (ctx, ss) {
            // Month label for the header
            final sheetMonth = monthFromPage(currentPageIndex);
            final bool isCurrentMonth =
                sheetMonth.year == today.year &&
                sheetMonth.month == today.month;

            // ── Day grid for one month ─────────────────────────────
            Widget buildMonthGrid(DateTime month) {
              final firstWeekday = month.weekday; // Mon=1 … Sun=7
              final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
              final leadingBlanks = firstWeekday - 1;
              // Always show 6 complete rows so the grid height never changes
              // between months → no layout jank on swipe.
              const int totalRows = 6;
              final totalCells = totalRows * 7;

              // Days in previous month (for ghost cells)
              final prevMonth = DateTime(month.year, month.month - 1, 1);
              final daysInPrevMonth = DateTime(
                prevMonth.year,
                prevMonth.month + 1,
                0,
              ).day;

              return GridView.builder(
                key: PageStorageKey('grid_${month.year}_${month.month}'),
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1.05,
                ),
                itemCount: totalCells,
                itemBuilder: (_, i) {
                  // ── Ghost cells from previous month ────────────
                  if (i < leadingBlanks) {
                    final ghostDay = daysInPrevMonth - (leadingBlanks - 1 - i);
                    return Center(
                      child: Text(
                        '$ghostDay',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.12),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  // ── Ghost cells from next month ────────────────
                  final dayIndex = i - leadingBlanks + 1;
                  if (dayIndex > daysInMonth) {
                    final nextDay = dayIndex - daysInMonth;
                    return Center(
                      child: Text(
                        '$nextDay',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.12),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  final day = dayIndex;
                  final cellDate = DateTime(month.year, month.month, day);
                  final isToday = isSameDay(cellDate, today);
                  final isFuture = cellDate.isAfter(today);

                  // Range / single selection states
                  bool isSelected = false;
                  bool isInRange = false;
                  bool isRangeEdge = false;
                  if (rangeMode) {
                    if (rangeStart != null &&
                        isSameDay(cellDate, rangeStart!)) {
                      isSelected = true;
                      isRangeEdge = true;
                    } else if (rangeEnd != null &&
                        isSameDay(cellDate, rangeEnd!)) {
                      isSelected = true;
                      isRangeEdge = true;
                    } else if (rangeStart != null &&
                        rangeEnd != null &&
                        cellDate.isAfter(rangeStart!) &&
                        cellDate.isBefore(rangeEnd!)) {
                      isInRange = true;
                    }
                  } else {
                    isSelected =
                        singleSelected != null &&
                        isSameDay(cellDate, singleSelected!);
                  }

                  // Activity dot
                  Color dotColor = Colors.transparent;
                  if (!isFuture) {
                    final dKey = cellDate.toIso8601String().split('T')[0];
                    int cEaten = 0, cTarget = 2000;
                    if (isToday) {
                      cEaten = _status?['eaten'] ?? 0;
                      cTarget = _status?['target'] ?? 2000;
                    } else if (_historyData.containsKey(dKey)) {
                      final h = _historyData[dKey];
                      cEaten = (h['calories'] ?? 0).toInt();
                      cTarget = (_status?['target'] ?? 2000).toInt();
                    }
                    if (cEaten > 0 && cEaten >= cTarget) {
                      dotColor = AppColors.primaryColor;
                    } else if (cEaten > 0) {
                      dotColor = Colors.orangeAccent;
                    }
                  }

                  final Color bgColor = isSelected
                      ? AppColors.primaryColor
                      : isInRange
                      ? AppColors.primaryColor.withValues(alpha: 0.18)
                      : isToday
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent;

                  final Color textColor = isFuture
                      ? Colors.white.withValues(alpha: 0.18)
                      : isSelected
                      ? Colors.black
                      : isInRange
                      ? AppColors.primaryColor
                      : Colors.white;

                  // AnimatedScale only on selected / range-edge for a crisp
                  // spring-pop on tap — avoids rebuilding all cells on every
                  // swipe (the old TweenAnimationBuilder caused that jank).
                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () {
                            ss(() {
                              if (rangeMode) {
                                if (rangeStart == null ||
                                    (rangeStart != null && rangeEnd != null)) {
                                  rangeStart = cellDate;
                                  rangeEnd = null;
                                } else {
                                  if (cellDate.isBefore(rangeStart!)) {
                                    rangeEnd = rangeStart;
                                    rangeStart = cellDate;
                                  } else {
                                    rangeEnd = cellDate;
                                  }
                                }
                              } else {
                                singleSelected = cellDate;
                              }
                            });
                          },
                    child: AnimatedScale(
                      // easeOutBack is fine here – scale overshooting is
                      // intentional (gives a spring-pop feel) and safe.
                      scale: isSelected || isRangeEdge ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        // MUST NOT use easeOutBack here: it overshoots past 1,
                        // making blurRadius go negative → fatal assertion.
                        // easeOutCubic is smooth AND never exceeds [0,1].
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: isInRange && !isRangeEdge
                              ? BorderRadius.circular(6)
                              : BorderRadius.circular(50),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryColor.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 10, // fixed value, not animated
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                color: textColor,
                                fontSize: isSelected ? 14.0 : 13.0,
                                fontWeight: isToday || isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              child: Text('$day'),
                            ),
                            if (!isFuture &&
                                !isSelected &&
                                dotColor != Colors.transparent)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            // ── Preset range selector ─────────────────────────────
            Widget buildPresetChips() {
              final presets = [('7 днів', 6), ('Місяць', 29), ('3 місяці', 89)];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: presets.map((p) {
                    final to = today;
                    final from = today.subtract(Duration(days: p.$2));
                    final active =
                        rangeStart != null &&
                        rangeEnd != null &&
                        isSameDay(rangeStart!, from) &&
                        isSameDay(rangeEnd!, to);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => ss(() {
                          rangeStart = from;
                          rangeEnd = to;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primaryColor
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? AppColors.primaryColor
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            p.$1,
                            style: TextStyle(
                              color: active ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }

            // ── Bottom action bar ─────────────────────────────────
            Widget buildActions() {
              if (rangeMode) {
                final canExport = rangeStart != null && rangeEnd != null;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildPresetChips(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // CSV button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: canExport
                                  ? () => exportCSV(rangeStart!, rangeEnd!)
                                  : null,
                              icon: const Icon(
                                Icons.table_chart_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'CSV',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: canExport
                                    ? AppColors.primaryColor
                                    : Colors.white.withValues(alpha: 0.25),
                                side: BorderSide(
                                  color: canExport
                                      ? AppColors.primaryColor
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // PDF button
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: canExport
                                  ? () {
                                      closeContainer();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PdfTemplateScreen(
                                            from: rangeStart!,
                                            to: rangeEnd!,
                                            historyData: _historyData,
                                            statusData: _status,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: canExport
                                      ? LinearGradient(
                                          colors: [
                                            AppColors.primaryColor,
                                            AppColors.primaryColor.withValues(
                                              alpha: 0.65,
                                            ),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  color: canExport
                                      ? null
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: canExport
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primaryColor
                                                .withValues(alpha: 0.35),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: canExport
                                          ? Colors.black
                                          : Colors.white.withValues(
                                              alpha: 0.25,
                                            ),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Звіт PDF 📄',
                                      style: TextStyle(
                                        color: canExport
                                            ? Colors.black
                                            : Colors.white.withValues(
                                                alpha: 0.25,
                                              ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rangeStart != null || rangeEnd != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            rangeEnd != null
                                ? '${rangeStart!.day}.${rangeStart!.month}.${rangeStart!.year} – ${rangeEnd!.day}.${rangeEnd!.month}.${rangeEnd!.year}'
                                : 'Оберіть кінцеву дату…',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                );
              }
              // Single mode
              if (singleSelected == null) return const SizedBox(height: 16);
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date label
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${singleSelected!.day}.${singleSelected!.month}.${singleSelected!.year}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Premium stats button
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _openDayStats(singleSelected!);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryColor,
                              AppColors.primaryColor.withValues(alpha: 0.65),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.bar_chart_rounded,
                              color: Colors.black,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Статистика дня',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('📊', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.black,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.75,
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // ── Mode toggle & Close button ────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Animated month label
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position:
                                          Tween<Offset>(
                                            begin: const Offset(0, 0.2),
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: anim,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                      child: child,
                                    ),
                                  ),
                              child: Text(
                                '${_fullMonthName(sheetMonth.month)} ${sheetMonth.year}',
                                key: ValueKey(
                                  '${sheetMonth.year}-${sheetMonth.month}',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Range toggle pill
                          GestureDetector(
                            onTap: () => ss(() {
                              rangeMode = !rangeMode;
                              if (!rangeMode) {
                                rangeStart = null;
                                rangeEnd = null;
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: rangeMode
                                    ? AppColors.primaryColor.withValues(
                                        alpha: 0.2,
                                      )
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: rangeMode
                                      ? AppColors.primaryColor.withValues(
                                          alpha: 0.5,
                                        )
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    rangeMode
                                        ? Icons.date_range_rounded
                                        : Icons.calendar_today_rounded,
                                    color: rangeMode
                                        ? AppColors.primaryColor
                                        : Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    rangeMode ? 'Діапазон' : 'Експорт даних',
                                    style: TextStyle(
                                      color: rangeMode
                                          ? AppColors.primaryColor
                                          : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Close button
                          GestureDetector(
                            onTap: closeContainer,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Weekday header ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд']
                            .map(
                              (d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ── Swipeable month PageView (vertical) ──────────
                    Expanded(
                      child: PageView.builder(
                        controller: pageCtrl,
                        scrollDirection: Axis.vertical,
                        onPageChanged: (page) {
                          ss(() => currentPageIndex = page);
                        },
                        itemCount: totalMonths,
                        itemBuilder: (_, page) {
                          final month = monthFromPage(page);
                          return buildMonthGrid(month);
                        },
                      ),
                    ),

                    // ── Swipe hint ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.expand_less_rounded,
                            color: Colors.white.withValues(alpha: 0.25),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCurrentMonth ? 'Поточний місяць' : 'Свайпайте ↑↓',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more_rounded,
                            color: isCurrentMonth
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.25),
                            size: 16,
                          ),
                        ],
                      ),
                    ),

                    // ── Action bar ───────────────────────────────────
                    buildActions(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDayStats(DateTime date) {
    Map<String, dynamic> dayData;
    if (isSameDay(date, DateTime.now())) {
      dayData = _status ?? {};
    } else {
      final dKey = date.toIso8601String().split('T')[0];
      if (_historyData.containsKey(dKey)) {
        final h = _historyData[dKey];
        dayData = {
          'eaten': h['calories'] ?? 0,
          'target': _status?['target'] ?? 2000,
          'water': h['water'] ?? 0,
          'water_target': _status?['water_target'] ?? 2000,
          'protein': (h['protein'] ?? 0).toInt(),
          'fat': (h['fat'] ?? 0).toInt(),
          'carbs': (h['carbs'] ?? 0).toInt(),
          'target_p': _status?['target_p'] ?? 150,
          'target_f': _status?['target_f'] ?? 70,
          'target_c': _status?['target_c'] ?? 250,
        };
      } else {
        dayData = {
          'eaten': 0,
          'target': _status?['target'] ?? 2000,
          'water': 0,
          'water_target': _status?['water_target'] ?? 2000,
          'protein': 0,
          'fat': 0,
          'carbs': 0,
          'target_p': _status?['target_p'] ?? 150,
          'target_f': _status?['target_f'] ?? 70,
          'target_c': _status?['target_c'] ?? 250,
        };
      }
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, _) => DayStatsScreen(date: date, data: dayData),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  String _fullMonthName(int month) {
    const months = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень',
    ];
    return months[month - 1];
  }

  String _getDayLetter(DateTime date) {
    const daysUA = ['П', 'В', 'С', 'Ч', 'П', 'С', 'Н'];
    return daysUA[date.weekday - 1];
  }

  void _initDisplayValues(Map<String, dynamic> data) {
    if (!_displayValuesInitialized) {
      _displayEaten = (data['eaten'] ?? 0).toDouble();
      _displayProtein = (data['protein'] ?? 0).toDouble();
      _displayFat = (data['fat'] ?? 0).toDouble();
      _displayCarbs = (data['carbs'] ?? 0).toDouble();
      _displayWater = (data['water'] ?? 0).toDouble();
      _toEaten = _displayEaten;
      _toProtein = _displayProtein;
      _toFat = _displayFat;
      _toCarbs = _displayCarbs;
      _toWater = _displayWater;
      _displayValuesInitialized = true;
    }
  }

  void _animateToDay(DateTime newDate) {
    _fromEaten = _displayEaten;
    _fromProtein = _displayProtein;
    _fromFat = _displayFat;
    _fromCarbs = _displayCarbs;
    _fromWater = _displayWater;

    _selectedDate = newDate;
    final newData = _currentData;

    _toEaten = (newData['eaten'] ?? 0).toDouble();
    _toProtein = (newData['protein'] ?? 0).toDouble();
    _toFat = (newData['fat'] ?? 0).toDouble();
    _toCarbs = (newData['carbs'] ?? 0).toDouble();
    _toWater = (newData['water'] ?? 0).toDouble();

    _dayAnimController.reset();
    _dayAnimController.forward();
  }

  Widget _buildDashboardStats(Map<String, dynamic> data) {
    _initDisplayValues(data);

    if (!_dayAnimController.isAnimating) {
      _displayEaten = (data['eaten'] ?? 0).toDouble();
      _displayProtein = (data['protein'] ?? 0).toDouble();
      _displayFat = (data['fat'] ?? 0).toDouble();
      _displayCarbs = (data['carbs'] ?? 0).toDouble();
      _displayWater = (data['water'] ?? 0).toDouble();
    }

    final int eaten = _displayEaten.round();
    final int target = data['target'] ?? 2000;
    final int remaining = (target - eaten).clamp(0, target);

    final double p = _displayProtein;
    final double f = _displayFat;
    final double c = _displayCarbs;
    final int targetP = data['target_p'] ?? 150;
    final int targetF = data['target_f'] ?? 70;
    final int targetC = data['target_c'] ?? 250;

    final bool goalMet = eaten >= target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Arc + text in one container ──────────────────────────────────
        GestureDetector(
          onTap: () {
            // Tooltip visualization (Microanimation/Tooltip)
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Калорії: $eaten / $target. Залишилось: $remaining ккал',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.black87,
              ),
            );
          },
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double w = constraints.maxWidth;
                // Arc is a semicircle whose centre sits at the bottom of a 180-tall zone
                final double arcZoneH = 180.0;
                final double radius = min(w / 2, arcZoneH) - 10;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Ambient glow — sits at top of the SizedBox (arc zone)
                    Positioned(
                      top: arcZoneH - radius,
                      left: w / 2 - radius,
                      width: radius * 2,
                      height: radius,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(radius),
                          ),
                          gradient: RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: 0.85,
                            colors: [
                              AppColors.primaryColor.withValues(
                                alpha: goalMet ? 0.20 : 0.10,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Arc painter — occupies the top arcZoneH pixels
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: arcZoneH,
                      child: CustomPaint(
                        painter: CalorieArcPainter(
                          current: eaten.toDouble(),
                          target: target.toDouble(),
                          startColor: AppColors.primaryColor,
                          endColor: AppColors.primaryColor.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ),

                    // Text block — sits inside arc, pulled up
                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSameDay(_selectedDate, DateTime.now())
                                ? 'Сьогодні, ${_selectedDate.day} ${_getMonthName(_selectedDate.month)}'
                                : '${_selectedDate.day} ${_getMonthName(_selectedDate.month)}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '$eaten',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 52,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ккал',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: goalMet
                                  ? AppColors.primaryColor.withValues(
                                      alpha: 0.18,
                                    )
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: goalMet
                                    ? AppColors.primaryColor.withValues(
                                        alpha: 0.40,
                                      )
                                    : Colors.white.withValues(alpha: 0.07),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              goalMet
                                  ? '🎯  Ціль виконано!'
                                  : 'залишилось  $remaining ккал',
                              style: TextStyle(
                                color: goalMet
                                    ? AppColors.primaryColor
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // ── Macro mini-cards ─────────────────────────────────────────────
        Transform.translate(
          offset: const Offset(0, -25),
          child: Row(
            children: [
              Expanded(
                child: _buildMacroCard(
                  label: 'Білки',
                  icon: Icons.egg_alt_rounded,
                  current: p,
                  target: targetP,
                  color: const Color(0xFF4D9FFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroCard(
                  label: 'Вуглев.',
                  icon: Icons.grain_rounded,
                  current: c,
                  target: targetC,
                  color: const Color(0xFF9B7FFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroCard(
                  label: 'Жири',
                  icon: Icons.water_drop_rounded,
                  current: f,
                  target: targetF,
                  color: const Color(0xFFFF9F43),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Січня',
      'Лютого',
      'Березня',
      'Квітня',
      'Травня',
      'Червня',
      'Липня',
      'Серпня',
      'Вересня',
      'Жовтня',
      'Листопада',
      'Грудня',
    ];
    return months[month - 1];
  }

  /// Individual macro mini-card (no outer wrapper on the page)
  Widget _buildMacroCard({
    required String label,
    required IconData icon,
    required double current,
    required int target,
    required Color color,
  }) {
    final double pct = (target > 0 ? current / target : 0.0).clamp(0.0, 1.0);
    final bool done = current >= target && current > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: done ? 0.35 : 0.15),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon + label row
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (done)
                    Icon(Icons.check_circle_rounded, color: color, size: 13),
                ],
              ),
              const SizedBox(height: 8),
              // Value
              Text(
                '${current.toInt()}г',
                style: TextStyle(
                  color: done ? color : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'з $targetг',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Перевіряємо чи це перший запуск додатка за сьогоднішній день
  Future<bool> _checkIfFirstLaunchToday() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return false;

    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String key = 'last_weight_check_date_$userId';
    final String? lastCheckDate = prefs.getString(key);

    return lastCheckDate != today;
  }

  // Зберігаємо поточну дату як день коли було виконано перевірку ваги
  Future<void> _markTodayAsChecked() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String key = 'last_weight_check_date_$userId';
    await prefs.setString(key, today);
  }

  // Перевіряємо і показуємо діалог якщо потрібно
  Future<void> _checkAndShowDailyWeightDialog() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final bool isFirstLaunch = await _checkIfFirstLaunchToday();
    if (isFirstLaunch && mounted) {
      _showDailyWeightCheckDialog();
    }
  }

  // Показуємо діалогове вікно з питанням про зміну ваги
  void _showDailyWeightCheckDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.cardColor),
        ),
        title: Column(
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              color: AppColors.primaryColor,
              size: 48,
            ),
            SizedBox(height: 15),
            Text(
              "Оновлення ваги",
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          "Чи змінилася ваша вага сьогодні?",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _markTodayAsChecked();
                  _showWeightWheelPicker();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Внести зміни",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _markTodayAsChecked();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Я введу це пізніше",
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Показуємо колесо вибору ваги
  void _showWeightWheelPicker() async {
    double currentWeight = 70.0;
    final userId = await AuthService.getStoredUserId();
    final prefs = await SharedPreferences.getInstance();

    if (_status != null && _status!['weight'] != null) {
      double? w = double.tryParse(_status!['weight'].toString());
      if (w != null && w > 0) currentWeight = w;
    } else if (userId != null) {
      String? cachedProfile = prefs.getString('cached_profile_$userId');
      if (cachedProfile != null) {
        var profileData = jsonDecode(cachedProfile);
        if (profileData['weight'] != null) {
          double? w = double.tryParse(profileData['weight'].toString());
          if (w != null && w > 0) currentWeight = w;
        }
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => WeightUpdateSheet(
        currentWeight: currentWeight,
        onWeightUpdated: (newWeight) {
          setState(() {
            if (_status != null) _status!['weight'] = newWeight;
          });
          _showSuccessNotification("Вагу оновлено: $newWeight кг! 🎯");
          _fetchStatus();
        },
      ),
    );
  }

  Map<String, dynamic>? _getNextVitaminSchedule() {
    if (_vitamins.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    List<Map<String, dynamic>> upcomingDoses = [];

    for (final day in [today, tomorrow]) {
      for (final vitamin in _vitamins) {
        bool isActive = false;
        final freqType = vitamin['frequency_type'];
        final startDateStr = vitamin['start_date'];
        DateTime? startDate;
        if (startDateStr != null) {
          try {
            startDate = DateTime.parse(startDateStr);
            startDate = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
          } catch (_) {}
        }

        if (startDate != null && day.isBefore(startDate)) {
          continue;
        }

        if (freqType == 'every_day' || freqType == null) {
          isActive = true;
        } else if (freqType == 'week_days') {
          final daysStr = vitamin['frequency_data']?.toString() ?? '';
          final days = daysStr
              .split(',')
              .map((e) => int.tryParse(e))
              .where((e) => e != null)
              .toSet();
          if (days.contains(day.weekday)) {
            isActive = true;
          }
        } else if (freqType == 'interval') {
          final interval =
              int.tryParse(vitamin['frequency_data']?.toString() ?? '1') ?? 1;
          if (startDate != null) {
            final diff = day.difference(startDate).inDays;
            if (diff >= 0 && diff % interval == 0) {
              isActive = true;
            }
          }
        }

        if (!isActive) continue;

        final schedules = vitamin['schedules'] as List?;
        if (schedules == null || schedules.isEmpty) continue;

        for (final s in schedules) {
          final timeStr = s['time']?.toString() ?? '09:00';
          final parts = timeStr.split(':');
          final h = int.tryParse(parts[0]) ?? 9;
          final m = int.tryParse(parts[1]) ?? 0;
          final doseTime = DateTime(day.year, day.month, day.day, h, m);

          if (doseTime.isAfter(now)) {
            upcomingDoses.add({
              'vitamin': vitamin,
              'time': doseTime,
              'dose': s['dose']?.toString() ?? '',
            });
          }
        }
      }
    }

    if (upcomingDoses.isEmpty) {
      return null;
    }

    upcomingDoses.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );
    return upcomingDoses.first;
  }

  Widget _buildVitaminsSection() {
    if (_vitamins.isEmpty) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllVitaminsScreen(
                vitamins: _vitamins,
                onEdit: _editVitamin,
                onDelete: _deleteVitamin,
              ),
            ),
          );
        },
        child: _glassCard(
          borderRadius: 28,
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF71B280).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF71B280,
                          ).withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.medication_liquid_rounded,
                      color: Color(0xFF71B280),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Мої вітаміни",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.add_circle_outline,
                color: Colors.white.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
        ),
      );
    }

    final nextUnknown = _getNextVitaminSchedule();
    final nextDose =
        nextUnknown ??
        {
          'vitamin': _vitamins.first,
          'time': DateTime.now(),
          'dose': (_vitamins.first['schedules'] as List?)?.first['dose'] ?? '',
        };

    final vitamin = nextDose['vitamin'];
    final timeDate = nextDose['time'] as DateTime;
    final isToday = isSameDay(timeDate, DateTime.now());
    final timeStr =
        "${timeDate.hour.toString().padLeft(2, '0')}:${timeDate.minute.toString().padLeft(2, '0')}";
    final dayStr = isToday ? "Сьогодні" : "Завтра";

    IconData icon;
    switch (vitamin['type']) {
      case 'pill':
        icon = Icons.circle;
        break;
      case 'capsule':
        icon = Icons.change_history;
        break;
      case 'powder':
        icon = Icons.grain;
        break;
      case 'drops':
        icon = Icons.water_drop;
        break;
      case 'spray':
        icon = Icons.air;
        break;
      case 'injection':
        icon = Icons.vaccines;
        break;
      default:
        icon = Icons.medication;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllVitaminsScreen(
              vitamins: _vitamins,
              onEdit: _editVitamin,
              onDelete: _deleteVitamin,
            ),
          ),
        );
      },
      child: _glassCard(
        borderRadius: 28,
        padding: EdgeInsets.zero,
        glowColor: const Color(0xFF71B280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF71B280,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.medication_liquid_rounded,
                              color: Color(0xFF71B280),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Мої вітаміни",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_vitamins.length} додан${_vitamins.length == 1 ? 'ий' : 'их'}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF234D52), Color(0xFF1E3A42)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF234D52,
                                ).withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      vitamin['name'] ?? "Вітамін",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (vitamin['brand'] != null &&
                                      vitamin['brand']
                                          .toString()
                                          .isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        "(${vitamin['brand']})",
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "$dayStr $timeStr",
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 1,
                                    height: 12,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      nextDose['dose']?.toString() ?? "",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editVitamin(dynamic vitamin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddVitaminSheet(editVitamin: vitamin),
    ).then((_) {
      _fetchVitamins();
    });
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: AppColors.cardColor,
      highlightColor: AppColors.textSecondary.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(width: 150, height: 20, color: Colors.black),
            const SizedBox(height: 10),
            Container(width: 200, height: 30, color: Colors.black),
            const SizedBox(height: 30),
            Container(
              height: 115,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 25),
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesCarousel() {
    // Stories hidden as per user request
    return const SizedBox.shrink();
    /*
    final stories = _status?['stories'] as List? ?? [];
    if (stories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 115,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: stories.length,
            itemBuilder: (context, index) =>
                _buildStoryCard(stories[index], index, stories),
          ),
        ),
      ],
    );
    */
  }

  // ... (keeping _buildStoryCard helper if needed for future, or leaving it since it's used by commented out code)

  /*
  Widget _buildStoryCard(dynamic story, int index, List allStories) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, _, _) =>
                StoryViewScreen(stories: allStories, initialIndex: index),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                story['image_url'] ?? "",
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: AppColors.cardColor),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  story['title'] ?? "",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  */

  Widget _buildSleepCalculatorCard() {
    return Row(
      children: [
        Expanded(child: _buildSleepCard()),
        const SizedBox(width: 16),
        Expanded(child: _buildWeightCard()),
      ],
    );
  }

  Widget _buildSleepCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SmartSleepScreen()),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A1B38).withValues(alpha: 0.7),
                  const Color(0xFF1B1224).withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B3FC4).withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B3FC4).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B3FC4).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bedtime_rounded,
                    color: Color(0xFFD0AEFF),
                    size: 22,
                  ),
                ),
                const Spacer(),
                const Text(
                  "Сон",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Калькулятор",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeightCard() {
    double currentWeight = 0;
    if (_status != null) {
      currentWeight = double.tryParse(_status!['weight'].toString()) ?? 0;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WeightTrackerScreen()),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF162529).withValues(alpha: 0.7),
                  const Color(0xFF0F1A1C).withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C7DA0).withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_weightHistory.isNotEmpty && _weightHistory.length > 1)
                    Positioned(
                      bottom: -16,
                      left: -16,
                      right: -16,
                      height: 60,
                      child: Opacity(
                        opacity: 0.15,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            minX: _weightHistory.first.x,
                            maxX: _weightHistory.last.x,
                            minY:
                                _weightHistory.map((e) => e.y).reduce(min) - 1,
                            maxY:
                                _weightHistory.map((e) => e.y).reduce(max) + 1,
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _weightHistory,
                                isCurved: true,
                                color: const Color(0xFF89C2D9),
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(
                                    0xFF89C2D9,
                                  ).withValues(alpha: 0.2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C7DA0).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF2C7DA0,
                              ).withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.monitor_weight_rounded,
                          color: Color(0xFF89C2D9),
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "$currentWeight кг",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Оновлення ваги",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _calculateStreak() {
    int streak = 0;

    DateTime checkDate = DateTime.now().subtract(const Duration(days: 1));
    while (true) {
      String dKey = checkDate.toIso8601String().split('T')[0];
      if (_historyData.containsKey(dKey)) {
        final hData = _historyData[dKey];
        final eaten = (hData['calories'] ?? hData['eaten'] ?? 0).toInt();
        final target = (hData['target'] ?? 2000).toInt();
        if (eaten >= target && eaten > 0) {
          streak++;
        } else {
          break;
        }
      } else {
        break;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    final todayData = _status;
    if (todayData != null) {
      final eaten = (todayData['eaten'] ?? 0).toInt();
      final target = (todayData['target'] ?? 2000).toInt();
      if (eaten >= target && eaten > 0) {
        streak++;
      }
    }

    return streak;
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FiYou AI label and Streak Badge
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Text(
                          "FiYou AI",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_calculateStreak() > 0) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.2),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.orange,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_calculateStreak()} Днів',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _greetingText,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Mood Tracker persistence ────────────────────────────────────────
  Future<void> _loadMood() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final saved = prefs.getInt('mood_$today');
    if (mounted && saved != null) {
      setState(() => _selectedMood = saved);
    }
  }

  Future<void> _saveMood(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setInt('mood_$today', index);
    if (mounted) {
      setState(() => _selectedMood = index);
    }
  }

  // ── Activity Timeline rebuild ───────────────────────────────────────
  void _rebuildTimeline(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> items = [];

    // Calories
    final eaten = data['eaten'] ?? 0;
    if (eaten > 0) {
      items.add({
        'icon': Icons.restaurant_rounded,
        'color': AppColors.primaryColor,
        'title': 'Їжа залогована',
        'subtitle': '$eaten ккал з ${data['target'] ?? 2000}',
      });
    }

    // Macros
    final protein = data['protein'] ?? 0;
    final fat = data['fat'] ?? 0;
    final carbs = data['carbs'] ?? 0;
    if (protein > 0 || fat > 0 || carbs > 0) {
      items.add({
        'icon': Icons.pie_chart_rounded,
        'color': const Color(0xFF66BB6A),
        'title': 'Макронутрієнти',
        'subtitle': 'Б: $proteinг · Ж: $fatг · В: $carbsг',
      });
    }

    // Water
    final water = data['water'] ?? 0;
    if (water > 0) {
      items.add({
        'icon': Icons.water_drop_rounded,
        'color': Colors.blueAccent,
        'title': 'Вода',
        'subtitle': '$water мл з ${data['water_target'] ?? 2000} мл',
      });
    }

    // Vitamins
    if (_vitamins.isNotEmpty) {
      items.add({
        'icon': Icons.medication_rounded,
        'color': const Color(0xFF71B280),
        'title': 'Вітаміни',
        'subtitle': '${_vitamins.length} додано',
      });
    }

    // Mood
    if (_selectedMood != null) {
      final mood = _moods[_selectedMood!];
      items.add({
        'icon': Icons.emoji_emotions_rounded,
        'color': mood['color'] as Color,
        'title': 'Настрій',
        'subtitle': '${mood['emoji']} ${mood['label']}',
      });
    }

    setState(() => _activityTimeline = items);
  }

  // ── Mood Tracker Widget ─────────────────────────────────────────────
  Widget _buildMoodTracker() {
    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      glowColor: _selectedMood != null
          ? _moods[_selectedMood!]['color'] as Color
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_emotions_rounded,
                color: _selectedMood != null
                    ? _moods[_selectedMood!]['color'] as Color
                    : Colors.white.withValues(alpha: 0.6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Як ти себе почуваєш?",
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_moods.length, (i) {
              final mood = _moods[i];
              final isSelected = _selectedMood == i;
              final color = mood['color'] as Color;

              return GestureDetector(
                onTap: () {
                  _saveMood(i);
                  _rebuildTimeline(_currentData);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 14 : 10,
                    vertical: isSelected ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Text(
                        mood['emoji'] as String,
                        style: TextStyle(fontSize: isSelected ? 24 : 20),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 2),
                        Text(
                          mood['label'] as String,
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Activity Timeline Widget ────────────────────────────────────────
  Widget _buildActivityTimeline() {
    if (_activityTimeline.isEmpty) return const SizedBox.shrink();

    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                color: AppColors.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Активність сьогодні",
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_activityTimeline.length}',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(_activityTimeline.length, (i) {
            final item = _activityTimeline[i];
            final isLast = i == _activityTimeline.length - 1;
            final color = item['color'] as Color;

            return Stack(
              children: [
                if (!isLast)
                  Positioned(
                    top: 28, // Begin line after the icon (icon is 28)
                    bottom:
                        0, // Extend to the bottom of the Stack (which is sized by the Row)
                    left:
                        15.25, // Center the 1.5 width line within the 32 width icon container
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon node
                    Container(
                      width: 32,
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: color,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['subtitle'] as String,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWaterTracker(int current, int target) {
    double progress = (target > 0 ? current / target : 0.0).clamp(0.0, 1.0);
    int percentage = (progress * 100).toInt();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaterDetailsScreen(
              currentWater: current,
              targetWater: target,
              onAddWater: (amount) => addWater(amount),
              historyData: _historyData,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 140),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.2),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blueAccent.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, fillHeight, child) {
                          // Enhanced Water Animation
                          return CustomPaint(
                            painter: WaterWavePainter(
                              fillHeight: fillHeight,
                              wavePhase: _waveController.value,
                              color: Colors
                                  .blueAccent, // Use full color base, painter will handle alphas
                              backgroundColor: Colors.transparent,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.water_drop,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Водний баланс",
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: current),
                              duration: const Duration(seconds: 2),
                              curve: Curves.easeOut,
                              builder: (context, value, child) => Text(
                                "$value / $target мл",
                                style: TextStyle(
                                  color: Colors.blueAccent.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TweenAnimationBuilder<int>(
                                  tween: IntTween(begin: 0, end: percentage),
                                  duration: const Duration(seconds: 2),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) => Text(
                                    "$value%",
                                    style: TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Денної норми води",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: GestureDetector(
                              onTap: () => addWater(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      "Додати",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ), // close Stack
          ), // close Container
        ), // close BackdropFilter
      ), // close ClipRRect
    ); // close InkWell
  } // close _buildWaterTracker
} // close HomeScreenState

class AddVitaminSheet extends StatefulWidget {
  final dynamic editVitamin;

  const AddVitaminSheet({super.key, this.editVitamin});

  @override
  State<AddVitaminSheet> createState() => _AddVitaminSheetState();
}

class _AddVitaminSheetState extends State<AddVitaminSheet> {
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _brandCtrl = TextEditingController();
  String _selectedType = 'pill';

  String _frequency = 'every_day';
  final List<int> _selectedWeekDays = [];
  int _intervalDays = 2;
  DateTime _startDate = DateTime.now();

  final List<Map<String, String>> _schedules = [];

  final Map<String, IconData> _types = {
    'pill': Icons.circle,
    'capsule': Icons.change_history,
    'powder': Icons.grain,
    'drops': Icons.water_drop,
    'spray': Icons.air,
    'injection': Icons.vaccines,
  };

  final Map<String, String> _typeNames = {
    'pill': 'Таблетки',
    'capsule': 'Капсули',
    'powder': 'Порошок',
    'drops': 'Краплі',
    'spray': 'Спрей',
    'injection': 'Уколи',
  };

  @override
  void initState() {
    super.initState();
    NotificationService().requestPermissions();

    // Якщо редагуємо існуючий вітамін, заповнюємо поля
    if (widget.editVitamin != null) {
      _nameCtrl.text = widget.editVitamin['name'] ?? '';
      _descCtrl.text = widget.editVitamin['description'] ?? '';
      _brandCtrl.text = widget.editVitamin['brand'] ?? '';
      _selectedType = widget.editVitamin['type'] ?? 'pill';

      if (widget.editVitamin['frequency_type'] != null) {
        _frequency = widget.editVitamin['frequency_type'];
      }

      if (widget.editVitamin['start_date'] != null) {
        try {
          _startDate = DateTime.parse(widget.editVitamin['start_date']);
        } catch (e) {
          debugPrint('Error parsing start date: $e');
        }
      }

      if (widget.editVitamin['schedules'] != null) {
        final schedules = widget.editVitamin['schedules'] as List;
        for (var schedule in schedules) {
          _schedules.add({
            'time': schedule['time']?.toString() ?? '',
            'dose': schedule['dose']?.toString() ?? '',
          });
        }
      }
    }
  }

  void _nextPage() {
    if (_currentStep < 2) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _saveVitamin();
    }
  }

  Future<void> _saveVitamin() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Введіть назву!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Додайте хоча б один час прийому!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    final data = {
      "user_id": userId,
      "name": _nameCtrl.text,
      "description": _descCtrl.text,
      "brand": _brandCtrl.text,
      "type": _selectedType,
      "frequency_type": _frequency,
      "frequency_data": _frequency == 'week_days'
          ? _selectedWeekDays.join(',')
          : _frequency == 'interval'
          ? _intervalDays.toString()
          : null,
      "start_date": _startDate.toIso8601String(),
      "schedules": _schedules,
    };

    try {
      final http.Response res;
      if (widget.editVitamin != null && widget.editVitamin['id'] != null) {
        res = await http.put(
          Uri.parse(
            '${AuthService.baseUrl}/vitamins/${widget.editVitamin['id']}',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );
      } else {
        res = await http.post(
          Uri.parse('${AuthService.baseUrl}/add_vitamin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );
      }

      if (res.statusCode == 200) {
        if (mounted) {
          _scheduleNotifications();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.editVitamin != null
                    ? "Вітамін оновлено! 💊"
                    : "Вітаміни додано! 💊",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Error ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Save Vitamin Error: $e");
    }
  }

  void _scheduleNotifications() {
    for (var i = 0; i < _schedules.length; i++) {
      final schedule = _schedules[i];
      final timeParts = schedule['time']!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final notificationId = (_nameCtrl.text + i.toString()).hashCode;

      final messages = [
        "Час подбати про здоров'я! 🌿 Прийміть ${_nameCtrl.text}",
        "Не забудьте про ${_nameCtrl.text}! 💊 Ваше тіло подякує.",
        "Дзелень! Час вітамінів: ${_nameCtrl.text} ✨",
        "Здоров'я понад усе! Прийміть ${_nameCtrl.text} 💪",
      ];
      final randomMessage = messages[Random().nextInt(messages.length)];

      NotificationService().scheduleDailyNotification(
        id: notificationId,
        title: randomMessage,
        body: "Дозування: ${schedule['dose']}",
        hour: hour,
        minute: minute,
      );
    }
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Основна інформація",
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildInput("Назва", _nameCtrl),
          const SizedBox(height: 15),
          _buildInput("Опис (опціонально)", _descCtrl, maxLength: 30),
          const SizedBox(height: 15),
          _buildInput("Фірма (опціонально)", _brandCtrl),
          const SizedBox(height: 25),
          Text(
            "Тип вітамінів",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: _types.entries
                .map((e) => _buildTypeItem(e.key, e.value))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeItem(String key, IconData icon) {
    bool isSelected = _selectedType == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = key),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryColor : AppColors.cardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.black : AppColors.textWhite,
              size: 24,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _typeNames[key]!,
            style: TextStyle(
              color: isSelected
                  ? AppColors.primaryColor
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: RadioGroup<String>(
        groupValue: _frequency,
        onChanged: (val) {
          if (val != null) {
            setState(() => _frequency = val);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Графік прийому",
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildFreqOption("Кожен день", "every_day"),
            _buildFreqOption("Інтервал (дні)", "interval"),
            if (_frequency == 'interval')
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 10),
                child: _buildNumberStepper(
                  "Кожні $_intervalDays дні",
                  _intervalDays,
                  (v) => setState(() => _intervalDays = v),
                ),
              ),
            _buildFreqOption("Дні тижня", "week_days"),
            if (_frequency == 'week_days') _buildWeekDaysSelector(),
            const SizedBox(height: 25),
            Text(
              "Дата початку",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 10),
            _buildDatePickerWheel(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Час і дозування",
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ..._schedules.map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${s['time']} - ${s['dose'] ?? 'Не вказано'}",
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _schedules.remove(s)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: ElevatedButton.icon(
              onPressed: _showTimeDoseDialog,
              icon: const Icon(Icons.add),
              label: const Text("Додати час"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardColor,
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimeDoseDialog() {
    int selectedHour = 9;
    int selectedMinute = 0;

    String doseSuffix = "шт";
    if (_selectedType == 'powder') doseSuffix = "г";
    if (_selectedType == 'drops') doseSuffix = "крапель";
    if (_selectedType == 'spray') doseSuffix = "пшиків";
    if (_selectedType == 'injection') doseSuffix = "мл";

    TextEditingController doseCtrl = TextEditingController(
      text: "1 $doseSuffix",
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 350,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: AppColors.cardColor),
        ),
        child: Column(
          children: [
            Text(
              "Оберіть час і дозу",
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => selectedHour = i,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 24,
                        builder: (c, i) => Center(
                          child: Text(
                            "$i".padLeft(2, '0'),
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    ":",
                    style: TextStyle(color: AppColors.textWhite, fontSize: 24),
                  ),
                  SizedBox(
                    width: 60,
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => selectedMinute = i,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 60,
                        builder: (c, i) => Center(
                          child: Text(
                            "$i".padLeft(2, '0'),
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: doseCtrl,
              maxLength: 30,
              style: TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                labelText: "Дозування (напр. 1 $doseSuffix)",
                labelStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.cardColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.cardColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (doseCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Будь ласка, введіть дозування"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                setState(() {
                  _schedules.add({
                    "time":
                        "${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}",
                    "dose": doseCtrl.text.trim(),
                  });
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.black,
              ),
              child: const Text("Додати"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerWheel() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _simpleWheel(
            31,
            _startDate.day,
            (v) => setState(
              () => _startDate = DateTime(
                _startDate.year,
                _startDate.month,
                v + 1,
              ),
            ),
          ),
          _simpleWheel(
            12,
            _startDate.month - 1,
            (v) => setState(
              () =>
                  _startDate = DateTime(_startDate.year, v + 1, _startDate.day),
            ),
            labels: [
              "Січ",
              "Лют",
              "Бер",
              "Кві",
              "Тра",
              "Чер",
              "Лип",
              "Сер",
              "Вер",
              "Жов",
              "Лис",
              "Гру",
            ],
          ),
          _simpleWheel(
            10,
            0,
            (v) => setState(
              () => _startDate = DateTime(
                DateTime.now().year + v,
                _startDate.month,
                _startDate.day,
              ),
            ),
            offset: DateTime.now().year,
          ),
        ],
      ),
    );
  }

  Widget _simpleWheel(
    int count,
    int initial,
    Function(int) onChanged, {
    List<String>? labels,
    int offset = 0,
  }) {
    return SizedBox(
      width: 60,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 35,
        perspective: 0.005,
        controller: FixedExtentScrollController(
          initialItem: initial > count ? 0 : initial,
        ),
        onSelectedItemChanged: onChanged,
        physics: const FixedExtentScrollPhysics(),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (c, i) => Center(
            child: Text(
              labels != null
                  ? labels[i]
                  : "${i + 1 + (offset > 0 ? offset - 1 : 0)}",
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController ctrl, {
    int? maxLength,
  }) {
    return TextField(
      controller: ctrl,
      maxLength: maxLength,
      style: TextStyle(color: AppColors.textWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFreqOption(String title, String val) {
    return RadioListTile<String>(
      title: Text(title, style: TextStyle(color: AppColors.textWhite)),
      value: val,
      activeColor: AppColors.primaryColor,
    );
  }

  Widget _buildWeekDaysSelector() {
    return Wrap(
      spacing: 8,
      children: List.generate(7, (index) {
        bool isSel = _selectedWeekDays.contains(index + 1);
        return ChoiceChip(
          label: Text(["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "НД"][index]),
          selected: isSel,
          selectedColor: AppColors.primaryColor,
          labelStyle: TextStyle(
            color: isSel ? Colors.black : AppColors.textWhite,
          ),
          backgroundColor: AppColors.cardColor,
          onSelected: (v) {
            setState(() {
              v
                  ? _selectedWeekDays.add(index + 1)
                  : _selectedWeekDays.remove(index + 1);
            });
          },
        );
      }),
    );
  }

  Widget _buildNumberStepper(String text, int val, Function(int) onChanged) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.remove, color: AppColors.textWhite),
          onPressed: () => val > 1 ? onChanged(val - 1) : null,
        ),
        Text(text, style: TextStyle(color: AppColors.textWhite)),
        IconButton(
          icon: Icon(Icons.add, color: AppColors.textWhite),
          onPressed: () => onChanged(val + 1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: AppColors.cardColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    3,
                    (index) => Container(
                      margin: const EdgeInsets.only(right: 5),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentStep == index
                            ? AppColors.primaryColor
                            : AppColors.textSecondary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentStep == 2 ? "ГОТОВО" : "ДАЛІ",
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.cardColor, height: 1),

          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildStep1(), _buildStep2(), _buildStep3()],
            ),
          ),
        ],
      ),
    );
  }
}

class DottedCirclePainter extends CustomPainter {
  final Color color;
  final Color? glowColor;

  DottedCirclePainter({required this.color, this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final int count = 12;

    if (glowColor != null) {
      final glowPaint = Paint()
        ..color = glowColor!
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      for (int i = 0; i < count; i++) {
        double angle = (2 * pi * i) / count;
        double x = radius + (radius - 1) * cos(angle);
        double y = radius + (radius - 1) * sin(angle);
        canvas.drawCircle(Offset(x, y), 3.0, glowPaint);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      double angle = (2 * pi * i) / count;
      double x = radius + (radius - 1) * cos(angle);
      double y = radius + (radius - 1) * sin(angle);
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DottedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glowColor != glowColor;
}

class CalorieArcPainter extends CustomPainter {
  final double current;
  final double target;
  final Color startColor;
  final Color endColor;

  CalorieArcPainter({
    required this.current,
    required this.target,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final double radius = min(size.width / 2, size.height) - 10;

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [startColor, endColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          startColor.withValues(alpha: 0.5),
          endColor.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi,
      pi,
      false,
      bgPaint,
    );

    double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi,
        pi * progress,
        false,
        glowPaint,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi,
      pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CalorieArcPainter oldDelegate) =>
      oldDelegate.current != current || oldDelegate.target != target;
}

class MacroRingPainter extends CustomPainter {
  final double percent;
  final Color color;

  MacroRingPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(center, radius, bgPaint);

    if (percent > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * percent,
        false,
        glowPaint,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * percent,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MacroRingPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color;
}

class WaterWavePainter extends CustomPainter {
  final double fillHeight;
  final double wavePhase;
  final Color color;
  final Color backgroundColor;

  WaterWavePainter({
    required this.fillHeight,
    required this.wavePhase,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor != Colors.transparent) {
      final bgPaint = Paint()..color = backgroundColor;
      canvas.drawRect(Offset.zero & size, bgPaint);
    }

    if (fillHeight <= 0) return;

    const double safeZone = 55.0;
    final double maxWaveHeight = max(0.0, size.height - safeZone);
    final effectiveHeight = maxWaveHeight * fillHeight;

    final baseY = size.height - effectiveHeight;

    // Vibrant liquid colors
    final wavePaint1 = Paint()..color = color.withValues(alpha: 0.5);
    final wavePaint2 = Paint()..color = color.withValues(alpha: 0.35);
    final wavePaint3 = Paint()..color = color.withValues(alpha: 0.2);

    // Make the waves more dynamic and liquid
    final baseWaveHeight = 15.0;

    _drawWave(
      canvas,
      size,
      baseHeight: baseY,
      waveHeight: baseWaveHeight,
      waveLength: size.width * 1.1,
      phase: wavePhase,
      paint: wavePaint1,
    );
    _drawWave(
      canvas,
      size,
      baseHeight: baseY + baseWaveHeight / 1.5,
      waveHeight: baseWaveHeight * 1.3,
      waveLength: size.width * 1.5,
      phase: wavePhase + 0.3,
      paint: wavePaint2,
    );
    _drawWave(
      canvas,
      size,
      baseHeight: baseY - baseWaveHeight / 2,
      waveHeight: baseWaveHeight * 0.8,
      waveLength: size.width * 0.9,
      phase: wavePhase + 0.7,
      paint: wavePaint3,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double baseHeight,
    required double waveHeight,
    required double waveLength,
    required double phase,
    required Paint paint,
  }) {
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);

    for (double x = 0; x <= size.width; x++) {
      final y =
          baseHeight +
          sin((x / waveLength * 2 * pi) + (phase * 2 * pi)) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaterWavePainter oldDelegate) =>
      oldDelegate.fillHeight != fillHeight ||
      oldDelegate.wavePhase != wavePhase ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}
