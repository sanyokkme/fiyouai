import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/data_manager.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../constants/app_colors.dart';
import 'package:flutter_app/widgets/weight_update_sheet.dart';
import 'package:flutter_app/screens/story_view_screen.dart';
import 'package:flutter_app/screens/all_vitamins_screen.dart';

bool hasPlayedConfettiGlobal = false;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _status;
  List<dynamic> _vitamins = [];
  bool _isLoading = true;
  late ConfettiController _confettiController;
  late PageController _pageController;
  String _greetingText = "Привіт!";

  // --- WEEKLY CALENDAR STATE ---
  DateTime _selectedDate = DateTime.now();
  final Map<String, dynamic> _historyData = {}; // Key: 'yyyy-MM-dd'

  Timer? _pollingTimer;
  bool _isFirstNetworkLoad = true;
  bool _showAllVitamins = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _pageController = PageController(viewportFraction: 0.32);

    _requestNotificationPermissions();

    _fetchStatus();
    _fetchHistory(); // Fetch historical data
    _fetchVitamins();

    // Перевірка чи це перший вхід за день і показ діалогу при потребі
    _checkAndShowDailyWeightDialog();

    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _fetchStatus(isPolling: true);
      _fetchVitamins();
    });
  }

  Future<void> _requestNotificationPermissions() async {
    await NotificationService().requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
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

    DataManager().prefetchAllData();

    try {
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/user_status/$userId'),
      );

      if (res.statusCode == 200) {
        final newData = jsonDecode(res.body);

        // 🔍 ДЕТАЛЬНЕ ЛОГУВАННЯ ДАНИХ З БЕКЕНДУ
        print('\n═══════════════════════════════════════');
        print('🏠 HOME SCREEN: Отримано дані з бекенду');
        print('═══════════════════════════════════════');
        print('📍 Endpoint: /user_status/$userId');
        print('📦 Raw Response Body:');
        print(res.body);
        print('\n📊 Parsed Data:');
        print('  • Eaten: ${newData['eaten']}');
        print('  • Target: ${newData['target']}');
        print('  • target_p: ${newData['target_p']}');
        print('  • target_f: ${newData['target_f']}');
        print('  • target_c: ${newData['target_c']}');
        print('  • protein: ${newData['protein']}');
        print('  • fat: ${newData['fat']}');
        print('  • carbs: ${newData['carbs']}');
        print('  • goal: ${newData['goal']}');
        print('  • water: ${newData['water']}');
        print('  • water_target: ${newData['water_target']}');
        print('═══════════════════════════════════════\n');

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
          _updateGreeting(newData['name'] ?? newData['username']);

          bool waterMet =
              (newData['water'] ?? 0) >= (newData['water_target'] ?? 2000);
          bool foodMet =
              ((newData['eaten'] ?? 0) >= (newData['target'] ?? 2000)) &&
              ((newData['eaten'] ?? 0) > 0);

          // Confetti plays only if it's NOT the first load, goal is met, and hasn't played yet this session
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

  Future<void> _fetchVitamins() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    try {
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/vitamins/$userId'),
      );
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

  Future<void> _deleteVitamin(String id) async {
    try {
      final res = await http.delete(
        Uri.parse('${AuthService.baseUrl}/vitamins/$id'),
      );
      if (res.statusCode == 200) {
        _showSuccessNotification("Вітамін видалено 🗑️");
        _fetchVitamins();
      }
    } catch (e) {
      debugPrint("Error deleting vitamin: $e");
    }
  }

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

  Future<void> addWater([int amount = 250]) async {
    try {
      final userId = await AuthService.getStoredUserId();
      final String timestamp = DateTime.now().toIso8601String();
      if (_status != null) {
        setState(() => _status!['water'] = (_status!['water'] ?? 0) + amount);
      }

      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/add_water'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": userId,
          "amount": amount,
          "created_at": timestamp,
        }),
      );
      if (res.statusCode == 200) _fetchStatus();
    } catch (e) {
      debugPrint("Water Error: $e");
    }
  }

  Future<void> _fetchHistory() async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    try {
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/analytics/$userId'),
      );

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

  Map<String, dynamic> get _currentData {
    if (isSameDay(_selectedDate, DateTime.now())) {
      return _status ?? {};
    }

    String dateKey = _selectedDate.toIso8601String().split('T')[0];
    if (_historyData.containsKey(dateKey)) {
      final hist = _historyData[dateKey];
      // Map history data to status structure
      return {
        'eaten': hist['calories'] ?? 0,
        'target': _status?['target'] ?? 2000, // Use current target as fallback
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

    // Return empty/zero data if no history found
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

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ... existing methods ...

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

    return Container(
      color: AppColors.backgroundDark,
      child: AppColors.buildBackgroundWithBlurSpots(
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
                      padding: const EdgeInsets.only(
                        bottom: 100,
                      ), // Add padding for bottom bar
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
                          const SizedBox(height: 20),
                          _buildStoriesCarousel(),
                          const SizedBox(height: 20),

                          // WEEKLY CALENDAR
                          _buildWeeklyCalendar(),

                          const SizedBox(height: 25),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSameDay(_selectedDate, DateTime.now())
                                      ? "Сьогоднішня статистика"
                                      : "Статистика за ${_getFullDayName(_selectedDate)}",
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                _buildMultiChart(
                                  currentData['eaten'] ?? 0,
                                  currentData['target'] ?? 2000,
                                  data: currentData, // Pass full data
                                ),
                                const SizedBox(height: 25),
                                _buildWaterTracker(
                                  currentData['water'] ?? 0,
                                  currentData['water_target'] ?? 2000,
                                ),
                                const SizedBox(height: 25),
                                _buildVitaminsSection(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40), // Extra space at bottom
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
            // FloatingBottomNavBar removed from here
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(7, (index) {
          final date = DateTime.now().subtract(Duration(days: 6 - index));
          final isSelected = isSameDay(date, _selectedDate);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              child: Container(
                margin: EdgeInsets.only(right: index == 6 ? 0 : 6),
                height: 65,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryColor
                      : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      _getDayName(date),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? null
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        date.day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : AppColors.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getDayName(DateTime date) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    return days[date.weekday - 1];
  }

  String _getFullDayName(DateTime date) {
    const days = [
      'Понеділок',
      'Вівторок',
      'Середу',
      'Четвер',
      'Пʼятницю',
      'Суботу',
      'Неділю',
    ];
    return days[date.weekday - 1];
  }

  // ========== Daily Weight Check Methods ==========

  /// Перевіряє чи це перший запуск додатка за сьогоднішній день
  Future<bool> _checkIfFirstLaunchToday() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return false;

    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String key = 'last_weight_check_date_$userId';
    final String? lastCheckDate = prefs.getString(key);

    return lastCheckDate != today;
  }

  /// Зберігає поточну дату як день коли було виконано перевірку ваги
  Future<void> _markTodayAsChecked() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String key = 'last_weight_check_date_$userId';
    await prefs.setString(key, today);
  }

  /// Перевіряє і показує діалог якщо потрібно
  Future<void> _checkAndShowDailyWeightDialog() async {
    // Невелика затримка перед показом діалогу
    await Future.delayed(const Duration(milliseconds: 500));

    final bool isFirstLaunch = await _checkIfFirstLaunchToday();
    if (isFirstLaunch && mounted) {
      _showDailyWeightCheckDialog();
    }
  }

  /// Показує діалогове вікно з питанням про зміну ваги
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
              // Кнопка "Внести зміни"
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
              // Кнопка "Я введу це пізніше"
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
          _fetchStatus(); // Ensure fresh sync
        },
      ),
    );
  }

  Widget _buildVitaminsSection() {
    // Hide vitamins for past dates as we don't have historical data for them yet
    if (!isSameDay(_selectedDate, DateTime.now()))
      return const SizedBox.shrink();

    if (_vitamins.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassCardColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Мої вітаміни",
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_vitamins.length}",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.cardColor, height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            itemCount: _showAllVitamins
                ? _vitamins.length
                : (_vitamins.length > 3 ? 3 : _vitamins.length),
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final vitamin = _vitamins[index];
              return _buildVitaminCard(vitamin);
            },
          ),
          if (_vitamins.length > 3)
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.cardColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Показати більше",
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward,
                      color: AppColors.primaryColor,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVitaminCard(dynamic vitamin) {
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
        _editVitamin(vitamin);
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vitamin['name'] ?? "Vitamin",
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blueAccent),
                  title: const Text(
                    "Редагувати",
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editVitamin(vitamin);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text(
                    "Видалити",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (vitamin['id'] != null) {
                      _deleteVitamin(vitamin['id'].toString());
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.glassCardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.glassCardColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.orangeAccent, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          vitamin['name'] ?? "No Name",
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vitamin['brand'] != null &&
                          vitamin['brand'].toString().isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "(${vitamin['brand']})",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (vitamin['description'] != null &&
                      vitamin['description'].toString().isNotEmpty)
                    Text(
                      vitamin['description'].toString().length > 30
                          ? '${vitamin['description'].toString().substring(0, 30)}...'
                          : vitamin['description'].toString(),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (vitamin['schedules'] != null &&
                      (vitamin['schedules'] as List).isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.medication_liquid,
                          color: AppColors.textSecondary,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vitamin['schedules'][0]['dose'] ?? 'Не вказано',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
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
  }

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
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_active,
                color: Colors.redAccent,
              ),
              onPressed: () async {
                await NotificationService().requestPermissions();
                await NotificationService().showInstantNotification(
                  "Тест",
                  "Це тестове сповіщення! 🔔",
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStyledCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.glassCardColor,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.glassCardColor),
    ),
    child: child,
  );

  Widget _buildMultiChart(int eaten, int target, {Map<String, dynamic>? data}) {
    final source = data ?? _status ?? {};
    double p = (source['protein'] ?? 0).toDouble();
    double f = (source['fat'] ?? 0).toDouble();
    double c = (source['carbs'] ?? 0).toDouble();
    int targetP = source['target_p'] ?? 120;
    int targetF = source['target_f'] ?? 70;
    int targetC = source['target_c'] ?? 250;
    int targetCals = source['target'] ?? 2000;
    int eatenCals = source['eaten'] ?? 0;

    // 🎨 ЛОГУВАННЯ ВІДОБРАЖУВАНИХ ДАНИХ
    print('\n🎨 HOME SCREEN: Відображення макросів');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Спожито: $eatenCals ккал');
    print('Ціль: $targetCals ккал');
    print('Макроси (спожито):');
    print('  • Білки: ${p.toInt()}г');
    print('  • Жири: ${f.toInt()}г');
    print('  • Вуглеводи: ${c.toInt()}г');
    print('Макроси (ціль):');
    print('  • Білки: ${targetP}г');
    print('  • Жири: ${targetF}г');
    print('  • Вуглеводи: ${targetC}г');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    bool goalReached = eatenCals >= targetCals;
    int remaining = targetCals - eatenCals;
    String goalText = _status?['goal'] == "lose"
        ? "Схуднення"
        : _status?['goal'] == "gain"
        ? "Набір маси"
        : "Підтримка ваги";
    IconData goalIcon = _status?['goal'] == "lose"
        ? Icons.trending_down
        : _status?['goal'] == "gain"
        ? Icons.trending_up
        : Icons.remove_red_eye;

    return _buildStyledCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showCalorieInfo,
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _ring(c, targetC, 120, Colors.purpleAccent),
                    _ring(p, targetP, 95, Colors.blueAccent),
                    _ring(f, targetF, 70, Colors.orangeAccent),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$eaten",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "ккал",
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 25),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            goalIcon,
                            size: 14,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            goalText.toUpperCase(),
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        goalReached ? "Статус" : "Залишилось",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goalReached ? "Ціль досягнута! 🎉" : "$remaining ккал",
                        style: TextStyle(
                          fontSize: goalReached ? 16 : 24,
                          fontWeight: FontWeight.bold,
                          color: goalReached
                              ? Colors.orangeAccent
                              : AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (eatenCals / targetCals).clamp(0.0, 1.0),
                          backgroundColor: AppColors.cardColor,
                          color: AppColors.primaryColor,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Ціль: $targetCals ккал",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Divider(color: AppColors.cardColor, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _compactMacroItem(
                "Білки",
                "${p.toInt()}",
                targetP,
                const Color(0xFF42A5F5),
              ),
              Container(width: 1, height: 30, color: AppColors.cardColor),
              _compactMacroItem(
                "Жири",
                "${f.toInt()}",
                targetF,
                const Color(0xFFFFA726),
              ),
              Container(width: 1, height: 30, color: AppColors.cardColor),
              _compactMacroItem(
                "Вугл.",
                "${c.toInt()}",
                targetC,
                const Color(0xFFAB47BC),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ring(double curr, int total, double size, Color color) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      value: total > 0 ? (curr / total).clamp(0.0, 1.0) : 0,
      strokeWidth: 8,
      color: color,
      backgroundColor: color.withValues(alpha: 0.1),
    ),
  );

  Widget _compactMacroItem(
    String label,
    String value,
    int target,
    Color color,
  ) => GestureDetector(
    onTap: () =>
        _showStyledModal(label, "Деталі про $label", color, Icons.info),
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextSpan(
                text: " / $targetг",
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildWaterTracker(int current, int target) {
    const int totalGlasses = 5;
    double mlsPerGlass = target / totalGlasses;
    return _buildStyledCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(
                "$current / $target мл",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => addWater(),
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.blueAccent,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              totalGlasses,
              (i) => _AnimatedGlass(
                fillAmount: ((current - (i * mlsPerGlass)) / mlsPerGlass).clamp(
                  0.0,
                  1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCalorieInfo() => _showStyledModal(
    "Ваша Ціль",
    "Баланс БЖВ важливий для результату.",
    AppColors.primaryColor,
    Icons.info_outline,
  );

  void _showStyledModal(
    String title,
    String text,
    Color color,
    IconData icon,
  ) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        border: Border.all(color: AppColors.cardColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 25),
          Icon(icon, color: color, size: 50),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.2),
              foregroundColor: color,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              "Зрозуміло",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AnimatedGlass extends StatelessWidget {
  final double fillAmount;
  const _AnimatedGlass({required this.fillAmount});
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.bottomCenter,
    children: [
      Icon(Icons.local_drink, size: 30, color: AppColors.cardColor),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fillAmount),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.elasticOut,
        builder: (context, value, child) => ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: value,
            child: Icon(
              Icons.local_drink,
              size: 30,
              color: Colors.blueAccent.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    ],
  );
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
        // Оновлюємо існуючий вітамін
        res = await http.put(
          Uri.parse(
            '${AuthService.baseUrl}/vitamins/${widget.editVitamin['id']}',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );
      } else {
        // Додаємо новий вітамін
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
