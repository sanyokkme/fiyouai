import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/data_manager.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Challenge> _activeChallenges = [];
  List<Challenge> _availableChallenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenges({bool isBackground = false}) async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    if (!isBackground && mounted) setState(() => _isLoading = true);

    final box = Hive.box('offlineDataBox');

    // Trigger background update
    if (!isBackground) {
      DataManager().prefetchAllData().then((_) {
        if (mounted) _loadChallenges(isBackground: true);
      });
    }
    final cachedHistory =
        box.get('cached_analytics_history_$userId') as String?;

    List history = [];
    if (cachedHistory != null) {
      history = jsonDecode(cachedHistory);
    }

    // Calculate stats for challenges
    int totalWater = 0;
    int daysWithWater2000 = 0;
    int daysWithCalories = 0;
    int daysWithProtein50 = 0;

    for (var day in history) {
      int water = ((day['water'] ?? 0) as num).toInt();
      totalWater += water;
      if (water >= 2000) daysWithWater2000++;
      if ((day['calories'] ?? 0) > 0) daysWithCalories++;
      if (((day['protein'] ?? 0) as num).toDouble() >= 50) daysWithProtein50++;
    }

    // Load joined challenges
    final joined = box.get('joined_challenges_$userId') as String?;
    Set<String> joinedIds = {};
    if (joined != null) {
      joinedIds = Set<String>.from(jsonDecode(joined));
    }

    // Define challenges
    final allChallenges = [
      Challenge(
        id: 'water_7day',
        title: 'Водний марафон 💧',
        description: 'Випивайте 2+ літри води 7 днів поспіль',
        icon: Icons.water_drop,
        color: Colors.blueAccent,
        category: 'Вода',
        currentValue: daysWithWater2000,
        targetValue: 7,
        rewardXP: 100,
        duration: '7 днів',
        participants: 247,
      ),
      Challenge(
        id: 'no_sugar_5',
        title: 'Без цукру 5 днів 🍬',
        description: 'Тримайте калорії нижче цілі 5 днів',
        icon: Icons.block,
        color: Colors.redAccent,
        category: 'Харчування',
        currentValue: 0,
        targetValue: 5,
        rewardXP: 75,
        duration: '5 днів',
        participants: 182,
      ),
      Challenge(
        id: 'protein_hero',
        title: 'Білковий герой 💪',
        description: 'Їжте 50+ г білка кожен день протягом тижня',
        icon: Icons.fitness_center,
        color: Colors.tealAccent,
        category: 'Білок',
        currentValue: daysWithProtein50,
        targetValue: 7,
        rewardXP: 120,
        duration: '7 днів',
        participants: 134,
      ),
      Challenge(
        id: 'tracking_14',
        title: 'Трекінг-марафон 📝',
        description: 'Записуйте їжу 14 днів поспіль',
        icon: Icons.edit_note,
        color: Colors.orangeAccent,
        category: 'Трекінг',
        currentValue: daysWithCalories,
        targetValue: 14,
        rewardXP: 150,
        duration: '14 днів',
        participants: 89,
      ),
      Challenge(
        id: 'early_bird',
        title: 'Рання пташка 🌅',
        description: 'Записуйте сніданок кожен день',
        icon: Icons.wb_sunny,
        color: Colors.amberAccent,
        category: 'Сніданок',
        currentValue: 0,
        targetValue: 7,
        rewardXP: 80,
        duration: '7 днів',
        participants: 312,
      ),
      Challenge(
        id: 'water_champion',
        title: 'Водний чемпіон 🏆',
        description: 'Випийте 50 літрів води загалом',
        icon: Icons.waves,
        color: Colors.cyanAccent,
        category: 'Вода',
        currentValue: totalWater,
        targetValue: 50000,
        rewardXP: 200,
        duration: '30 днів',
        participants: 56,
      ),
    ];

    final active = allChallenges
        .where((c) => joinedIds.contains(c.id))
        .toList();
    final available = allChallenges
        .where((c) => !joinedIds.contains(c.id))
        .toList();

    if (mounted) {
      setState(() {
        _activeChallenges = active;
        _availableChallenges = available;
        _isLoading = false;
      });
    }
  }

  Future<void> _joinChallenge(Challenge challenge) async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    final box = Hive.box('offlineDataBox');
    final joined = box.get('joined_challenges_$userId') as String?;
    Set<String> joinedIds = {};
    if (joined != null) {
      joinedIds = Set<String>.from(jsonDecode(joined));
    }

    joinedIds.add(challenge.id);
    await box.put('joined_challenges_$userId', jsonEncode(joinedIds.toList()));

    setState(() {
      _availableChallenges.remove(challenge);
      _activeChallenges.add(challenge);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎯 Ви приєдналися до "${challenge.title}"!'),
          backgroundColor: AppColors.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Glass Card
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: AppColors.textWhite,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Челенджі',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow, size: 18),
                            const SizedBox(width: 6),
                            Text('Активні (${_activeChallenges.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.explore, size: 18),
                            const SizedBox(width: 6),
                            Text('Доступні (${_availableChallenges.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildChallengeList(
                            _activeChallenges,
                            isActive: true,
                          ),
                          _buildChallengeList(
                            _availableChallenges,
                            isActive: false,
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

  Widget _buildChallengeList(
    List<Challenge> challenges, {
    required bool isActive,
  }) {
    if (challenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isActive ? '🎯' : '🏆', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              isActive
                  ? 'Ви ще не приєднались до жодного челенджу'
                  : 'Всі челенджі активовані!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: challenges.length + 1,
      itemBuilder: (context, index) {
        if (index == challenges.length) {
          return const SizedBox(height: 120);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildChallengeCard(challenges[index], isActive: isActive),
        );
      },
    );
  }

  Widget _buildChallengeCard(Challenge challenge, {required bool isActive}) {
    final progress = challenge.progress;
    final isComplete = challenge.isComplete;

    return _glassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      glowColor: isComplete ? Colors.greenAccent : challenge.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: challenge.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: challenge.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(challenge.icon, color: challenge.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.description,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          if (isActive) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete ? Colors.greenAccent : challenge.color,
                          ),
                          minHeight: 6,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: challenge.color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Bottom info
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: AppColors.textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        challenge.duration,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.people_outline,
                      color: AppColors.textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${challenge.participants}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${challenge.rewardXP} XP',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isActive) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _joinChallenge(challenge),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          challenge.color,
                          challenge.color.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Приєднатися',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String category;
  final int currentValue;
  final int targetValue;
  final int rewardXP;
  final String duration;
  final int participants;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.currentValue,
    required this.targetValue,
    required this.rewardXP,
    required this.duration,
    required this.participants,
  });

  bool get isComplete => currentValue >= targetValue;
  double get progress =>
      (targetValue > 0 ? currentValue / targetValue : 0.0).clamp(0.0, 1.0);
}
