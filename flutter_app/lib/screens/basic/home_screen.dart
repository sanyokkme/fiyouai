// Обовязкові імпорти
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Імпорти сервісів
import 'package:flutter_app/services/data_manager.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/services/notification_service.dart';

// Імпорти констант
import 'package:flutter_app/constants/app_colors.dart';
import 'package:fl_chart/fl_chart.dart'; // Add fl_chart import

// Імпорти віджетів
import 'package:flutter_app/widgets/weight_update_sheet.dart';

// Імпорти екранів
// import 'package:flutter_app/screens/story_view_screen.dart'; // Unused
import 'package:flutter_app/screens/all_vitamins_screen.dart';
import 'package:flutter_app/screens/sleep_calculator_screen.dart';
import 'package:flutter_app/screens/weight_tracker_screen.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    if (!isPolling) {
      String? cachedData = prefs.getString('cached_status_$userId');
      if (cachedData != null && _status == null) {
        if (mounted) {
          setState(() {
            _status = jsonDecode(cachedData);
            _isLoading = false;
          });
          _updateGreeting(_status!['name'] ?? _status!['username']);
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
        await prefs.setString('cached_status_$userId', res.body);
        if (mounted) {
          bool wasFirstLoad = _isFirstNetworkLoad;
          setState(() {
            _status = newData;
            _isLoading = false;
            _isFirstNetworkLoad = false;
          });
          _loadWeightHistory(); // Refresh weight history when new data comes
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
      if (res.statusCode == 200) _fetchStatus();
    } catch (e) {
      debugPrint("Water Error: $e");
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

    return AppColors.buildBackgroundWithBlurSpots(
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
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              _buildHeader(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildWeeklyCalendar(),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDashboardStats(currentData),
                              const SizedBox(height: 25),
                              _buildWaterTracker(
                                _dayAnimController.isAnimating
                                    ? _displayWater.round()
                                    : currentData['water'] ?? 0,
                                currentData['water_target'] ?? 2000,
                              ),
                              const SizedBox(height: 25),
                              _buildSleepCalculatorCard(),
                              const SizedBox(height: 25),
                              _buildVitaminsSection(),
                              const SizedBox(
                                height: 25,
                              ), // Spacer before Stories/Sleep

                              //_buildStoriesCarousel(),
                              // const SizedBox(height: 25),
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
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final dates = List.generate(
      7,
      (index) => index < 6 ? now.subtract(Duration(days: 5 - index)) : tomorrow,
    );

    int selectedIndex = dates.indexWhere((d) => isSameDay(d, _selectedDate));
    if (selectedIndex == -1) selectedIndex = 5;

    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / 7;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: List.generate(7, (index) {
                  final date = dates[index];
                  final isTomorrow = isSameDay(date, tomorrow);
                  final isSelected = index == selectedIndex;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isTomorrow ? null : () => _animateToDay(date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getDayLetter(date),
                            style: TextStyle(
                              color: isTomorrow && !isSelected
                                  ? AppColors.textSecondary.withValues(
                                      alpha: 0.4,
                                    )
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isSelected ? 0.0 : 1.0,
                              child: _buildDayIndicator(date, isTomorrow),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: selectedIndex * slotWidth + (slotWidth - 36) / 2,
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            dates[selectedIndex].day.toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
    );
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

    int eaten = _displayEaten.round();
    int target = data['target'] ?? 2000;
    int remaining = target - eaten;

    double p = _displayProtein;
    double f = _displayFat;
    double c = _displayCarbs;
    int targetP = data['target_p'] ?? 150;
    int targetF = data['target_f'] ?? 70;
    int targetC = data['target_c'] ?? 250;

    String remainingText = "Залишилось $remaining";
    if (eaten >= target) {
      remainingText = "Ціль виконано!";
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CustomPaint(
                size: const Size(300, 300),
                painter: CalorieArcPainter(
                  current: eaten.toDouble(),
                  target: target.toDouble(),
                  startColor: AppColors.primaryColor,
                  endColor: AppColors.primaryColor.withValues(alpha: 0.5),
                ),
              ),
              Positioned(
                bottom: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSameDay(_selectedDate, DateTime.now())
                          ? "Сьогодні ${_selectedDate.day} ${_getMonthName(_selectedDate.month)}"
                          : "${_selectedDate.day} ${_getMonthName(_selectedDate.month)}",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "$eaten",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "ккал",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
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

        Text(
          remainingText,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 25),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMacroCircle("Білки", p, targetP, Colors.blueAccent),
              _buildMacroCircle("Вугл", c, targetC, Colors.purpleAccent),
              _buildMacroCircle("Жири", f, targetF, Colors.orangeAccent),
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

  Widget _buildMacroCircle(
    String label,
    double current,
    int target,
    Color color,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: CustomPaint(
            painter: MacroRingPainter(
              percent: (target > 0 ? current / target : 0.0).clamp(0.0, 1.0),
              color: color,
            ),
            child: Center(
              child: Text(
                "${current.toInt()}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        Text(
          "$targetг",
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ],
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
    // Gradient decoration for consistent styling
    final gradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF134E5E), // Dark Teal
          const Color(0xFF71B280), // Light Green
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF134E5E).withOpacity(0.4),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );

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
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: gradientDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.medication, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
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
              Row(
                children: [
                  Text(
                    "Додати",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.add_circle_outline,
                    color: Colors.white.withOpacity(0.9),
                    size: 16,
                  ),
                ],
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
      child: Container(
        width: double.infinity,
        decoration: gradientDecoration,
        // Removed padding here to allow footer to be edge-to-edge
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(
                20,
              ), // Padding moved here for content
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.medication,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
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
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_vitamins.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    vitamin['name'] ?? "Vitamin",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (vitamin['brand'] != null &&
                                    vitamin['brand'].toString().isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      "(${vitamin['brand']})",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_filled,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$dayStr $timeStr",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 1,
                                  height: 10,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  nextDose['dose']?.toString() ?? "",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (vitamin['description'] != null &&
                                vitamin['description']
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                vitamin['description'].toString(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
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
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(
                    0.2,
                  ), // Slightly darker for contrast
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Керувати вітамінами",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 12,
                    ),
                  ],
                ),
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
    return Column(
      children: [
        _buildSleepCard(),
        const SizedBox(height: 20),
        _buildWeightCard(),
      ],
    );
  }

  Widget _buildSleepCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SleepCalculatorScreen()),
      ),
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          // Gradient background for "Sleep"
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2C0E56), // Deep purple
              const Color(0xFF5D2E8C), // Light purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C0E56).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                Icons.nights_stay_rounded,
                size: 80,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bedtime_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Калькулятор сну",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Розрахувати ідеальний час",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
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
      child: Container(
        width: double.infinity,
        height: 140, // Taller to fit graph
        decoration: BoxDecoration(
          // Gradient background for "Weight"
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F2027), // Dark Blue
              const Color(0xFF203A43), // Teal Blue
              const Color(0xFF2C5364), // Lighter Blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2027).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background Graph
              if (_weightHistory.isNotEmpty && _weightHistory.length > 1)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 40,
                    ), // Push graph down a bit
                    child: Opacity(
                      opacity: 0.3, // Slightly more visible on dark bg
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minX: _weightHistory.first.x,
                          maxX: _weightHistory.last.x,
                          minY: _weightHistory.map((e) => e.y).reduce(min) - 1,
                          maxY: _weightHistory.map((e) => e.y).reduce(max) + 1,
                          lineTouchData: const LineTouchData(
                            enabled: false,
                          ), // Disable touch interactions
                          lineBarsData: [
                            LineChartBarData(
                              spots: _weightHistory,
                              isCurved: true,
                              color: Colors
                                  .lightBlueAccent, // Lighter color for graph
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.lightBlueAccent.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.monitor_weight_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Вага",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "$currentWeight кг",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _weightHistory.isNotEmpty
                              ? "Останні оновлення"
                              : "Даних ще немає",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Детальніше",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "FiYou AI",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              _greetingText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaterTracker(int current, int target) {
    double progress = (target > 0 ? current / target : 0.0).clamp(0.0, 1.0);
    int percentage = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassCardColor),
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
                    return CustomPaint(
                      painter: WaterWavePainter(
                        fillHeight: fillHeight,
                        wavePhase: _waveController.value,
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        backgroundColor: Colors.transparent,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                            color: Colors.blueAccent.withValues(alpha: 0.9),
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
      ),
    );
  }
}

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

    final wavePaint1 = Paint()..color = color;
    final wavePaint2 = Paint()..color = color.withValues(alpha: 0.6);
    final wavePaint3 = Paint()..color = color.withValues(alpha: 0.3);

    _drawWave(
      canvas,
      size,
      baseHeight: baseY,
      waveHeight: 12,
      waveLength: size.width,
      phase: wavePhase,
      paint: wavePaint1,
    );
    _drawWave(
      canvas,
      size,
      baseHeight: baseY + 5,
      waveHeight: 15,
      waveLength: size.width * 1.4,
      phase: wavePhase + 0.3,
      paint: wavePaint2,
    );
    _drawWave(
      canvas,
      size,
      baseHeight: baseY - 5,
      waveHeight: 8,
      waveLength: size.width * 0.8,
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
