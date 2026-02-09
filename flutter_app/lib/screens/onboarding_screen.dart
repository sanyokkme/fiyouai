import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:ui'; // Needed for ImageFilter
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import 'package:flutter_app/screens/basic/register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentStep = 0;
  bool _isNameValid = false;

  // Animation Controllers for Background
  late AnimationController _bgAnimationController;
  // Blob animations
  late Animation<double> _blob1AlignX;
  late Animation<double> _blob1AlignY;
  late Animation<double> _blob2AlignX;
  late Animation<double> _blob2AlignY;
  late Animation<double> _blob3AlignX;
  late Animation<double> _blob3AlignY;

  // Animation Controller for Content Fade In
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Об'єкт для збору даних
  final Map<String, dynamic> userData = {
    "source": "",
    "name": "",
    "goal": "lose",
    "gender": "male",
    "dob": DateTime(DateTime.now().year - 18, 1, 1), // Default 18 years old
    "activity": "Сидячий",
    "height": 170.0,
    "weight": 70.0,
    "target_weight": 65.0, // Default for 'lose'
  };

  @override
  void initState() {
    super.initState();
    // Background Animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // Random-ish movement for blobs
    _blob1AlignX = Tween<double>(begin: -1.2, end: 1.2).animate(
      CurvedAnimation(
        parent: _bgAnimationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );
    _blob1AlignY = Tween<double>(begin: -1.2, end: -0.5).animate(
      CurvedAnimation(
        parent: _bgAnimationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _blob2AlignX = Tween<double>(begin: 1.2, end: -1.2).animate(
      CurvedAnimation(
        parent: _bgAnimationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );
    _blob2AlignY = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _bgAnimationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _blob3AlignX = Tween<double>(begin: -0.5, end: 0.5).animate(
      CurvedAnimation(
        parent: _bgAnimationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );
    _blob3AlignY = Tween<double>(begin: 0.8, end: -0.8).animate(
      CurvedAnimation(
        parent: _bgAnimationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    // Content Fade Animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Define Steps Count dynamically
  int get _totalSteps => userData['goal'] == 'maintain' ? 10 : 11;

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentStep = index);
    _fadeController.reset();
    _fadeController.forward();
  }

  void _validateName(String value) {
    setState(() {
      _isNameValid = value.trim().length >= 2;
      userData['name'] = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // --- ANIMATED BACKGROUND ---
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(color: AppColors.backgroundDark),
                  // Blob 1
                  Positioned(
                    top:
                        MediaQuery.of(context).size.height * 0.2 +
                        (100 * _blob1AlignY.value),
                    left:
                        MediaQuery.of(context).size.width * 0.5 +
                        (150 * _blob1AlignX.value),
                    child: _buildBlurBlob(AppColors.primaryColor, 300),
                  ),
                  // Blob 2
                  Positioned(
                    bottom:
                        MediaQuery.of(context).size.height * 0.2 +
                        (100 * _blob2AlignY.value),
                    right:
                        MediaQuery.of(context).size.width * 0.5 +
                        (150 * _blob2AlignX.value),
                    child: _buildBlurBlob(AppColors.brightPrimaryColor, 250),
                  ),
                  // Blob 3
                  Positioned(
                    top:
                        MediaQuery.of(context).size.height * 0.5 +
                        (100 * _blob3AlignY.value),
                    left:
                        MediaQuery.of(context).size.width * 0.2 +
                        (50 * _blob3AlignX.value),
                    child: _buildBlurBlob(AppColors.accentColor, 200),
                  ),
                  // General overlay to mesh them together
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(color: Colors.transparent),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    children: [
                      _buildAnimatedStep(_buildSourceStep()),
                      _buildAnimatedStep(_buildNameStep()),
                      _buildAnimatedStep(_buildGoalStep()),
                      _buildAnimatedStep(_buildGenderStep()),
                      _buildAnimatedStep(_buildDOBStep()),
                      _buildAnimatedStep(_buildActivityStep()),
                      _buildAnimatedStep(_buildHeightStep()),
                      _buildAnimatedStep(_buildWeightStep()),
                      // Logic: If goal is maintain, skip target weight step
                      if (userData['goal'] != 'maintain')
                        _buildAnimatedStep(_buildTargetWeightStep()),

                      _buildLoadingPlanStep(),
                      _buildAnimatedStep(_buildSummaryStep()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.4),
      ),
    );
  }

  Widget _buildTopBar() {
    // Hide on loading/summary
    // Adjust logic for dynamic steps
    if (_currentStep == _totalSteps - 2 || _currentStep == _totalSteps - 1)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: Icon(
                Icons.arrow_back_ios,
                color: AppColors.textSecondary,
                size: 20,
              ),
            )
          else
            const SizedBox(width: 40),

          Expanded(child: _buildSegmentedProgress()),

          const SizedBox(width: 40), // Balance spacing
        ],
      ),
    );
  }

  Widget _buildSegmentedProgress() {
    int totalBars = _totalSteps - 2; // Exclude loading and summary
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalBars, (index) {
        bool isActive = index <= _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 4,
          width: isActive ? 20 : 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryColor
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildAnimatedStep(Widget child) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: child),
    );
  }

  // --- CONTENT STEP BUILDERS ---

  Widget _buildSourceStep() {
    return _buildSelectionStep(
      "Звідки ви про нас дізнались?",
      ["Instagram", "TikTok", "App Store", "Google", "YouTube", "Інше"],
      (val) {
        userData['source'] = val;
        _nextPage();
      },
    );
  }

  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Як вас звати?",
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Це допоможе нам персоналізувати ваш досвід",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          _GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: TextField(
              controller: _nameController,
              style: TextStyle(color: AppColors.textWhite, fontSize: 20),
              textAlign: TextAlign.center,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "Введіть ім'я",
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                border: InputBorder.none,
              ),
              onChanged: _validateName,
            ),
          ),

          const SizedBox(height: 20),
          if (_isNameValid)
            Text(
              "✓ Чудове ім'я!",
              style: TextStyle(color: AppColors.primaryColor, fontSize: 14),
            ),

          const Spacer(),
          _buildBottomButton("ДАЛІ", _isNameValid ? _nextPage : null),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return _buildSelectionStep(
      "Ваша основна ціль?",
      ["Скинути вагу", "Утримати вагу", "Набрати вагу"],
      (val) {
        setState(() {
          if (val == "Скинути вагу")
            userData['goal'] = "lose";
          else if (val == "Набрати вагу")
            userData['goal'] = "gain";
          else
            userData['goal'] = "maintain";

          // Initialize default target weight based on current weight logic
          if (userData['goal'] == 'lose') {
            userData['target_weight'] = (userData['weight'] as double) - 5.0;
          } else if (userData['goal'] == 'gain') {
            userData['target_weight'] = (userData['weight'] as double) + 5.0;
          } else {
            userData['target_weight'] = userData['weight'];
          }
        });
        _nextPage();
      },
      icons: [Icons.trending_down, Icons.balance, Icons.trending_up],
    );
  }

  Widget _buildGenderStep() {
    return _buildSelectionStep("Ваша стать?", ["Чоловік", "Жінка"], (val) {
      userData['gender'] = val == "Чоловік" ? "male" : "female";
      _nextPage();
    }, icons: [Icons.male, Icons.female]);
  }

  Widget _buildDOBStep() {
    int currentYear = DateTime.now().year;
    return Column(
      children: [
        const Spacer(),
        Text(
          "Скільки вам років?",
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 300,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 60,
            perspective: 0.005,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              int age = index + 10;
              userData['dob'] = DateTime(currentYear - age, 1, 1);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: 90,
              builder: (context, index) {
                int age = index + 10;
                // Simple age calc
                int currentAge =
                    currentYear - (userData['dob'] as DateTime).year;
                bool isSelected = currentAge == age;

                return Center(
                  child: Text(
                    "$age",
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textWhite
                          : AppColors.textGrey,
                      fontSize: isSelected ? 32 : 24,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Spacer(),
        _buildBottomButton("ДАЛІ", _nextPage),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildActivityStep() {
    return _buildSelectionStep(
      "Рівень активності",
      [
        "Сидячий",
        "Легка активність",
        "Середня активність",
        "Висока активність",
      ],
      (val) {
        userData['activity_level'] = val;
        _nextPage();
      },
      icons: [
        Icons.chair,
        Icons.directions_walk,
        Icons.directions_run,
        Icons.fitness_center,
      ],
    );
  }

  Widget _buildHeightStep() {
    return _buildWheelStep(
      "Ваш ріст",
      100,
      230,
      "см",
      "height",
      (val) => setState(() => userData['height'] = val),
      userData['weight'],
    );
  }

  Widget _buildTargetWeightStep() {
    // Determine min/max for wheel based on goal
    double current = userData['weight'];
    bool isLose = userData['goal'] == 'lose';
    int min = isLose ? 30 : current.toInt();
    int max = isLose ? current.toInt() : 200;

    // Ensure current target is within bounds
    double target = userData['target_weight'] ?? current;
    if (isLose && target > current) target = current - 1;
    if (!isLose && target < current) target = current + 1;

    return _buildWheelStep(
      "Цільова вага",
      min,
      max,
      "кг",
      "target_weight",
      (val) => setState(() => userData['target_weight'] = val),
      target,
    );
  }

  Widget _buildWeightStep() {
    return _buildWheelStep("Ваша вага", 30, 200, "кг", "weight", (val) {
      setState(() {
        userData['weight'] = val;
        // Update default target if not set manually yet or just simple logic reset
        if (userData['goal'] == 'lose') userData['target_weight'] = val - 5;
        if (userData['goal'] == 'gain') userData['target_weight'] = val + 5;
      });
    }, userData['weight']);
  }

  Widget _buildLoadingPlanStep() {
    return _PlanLoadingAnimation(onComplete: _nextPage);
  }

  Widget _buildSummaryStep() {
    return _OnboardingSummary(
      userData: userData,
      onFinish: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterScreen(onboardingData: userData),
          ),
        );
      },
    );
  }

  // --- REUSABLE BUILDERS ---

  Widget _buildSelectionStep(
    String title,
    List<String> options,
    Function(String) onSelect, {
    List<IconData>? icons,
  }) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              return Theme(
                data: ThemeData(
                  splashColor: AppColors.primaryColor.withOpacity(0.3),
                ),
                child: InkWell(
                  onTap: () => onSelect(options[index]),
                  borderRadius: BorderRadius.circular(20),
                  child: _GlassContainer(
                    // Use GlassContainer here
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 20,
                    ),
                    child: Row(
                      children: [
                        if (icons != null && index < icons.length) ...[
                          Icon(
                            icons[index],
                            color: AppColors.textWhite,
                            size: 24,
                          ),
                          const SizedBox(width: 15),
                        ],
                        Text(
                          options[index],
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWheelStep(
    String title,
    int min,
    int max,
    String unit,
    String key,
    Function(double) onValChanged,
    double currentVal,
  ) {
    return Column(
      children: [
        const Spacer(),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Selection indicator - Glass style
              _GlassContainer(
                height: 60,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                color: AppColors.primaryColor.withOpacity(0.2), // Slight tint
              ),
              ListWheelScrollView.useDelegate(
                itemExtent: 60,
                perspective: 0.005,
                diameterRatio: 1.2,
                physics: const FixedExtentScrollPhysics(),
                controller: FixedExtentScrollController(
                  initialItem: currentVal.toInt() - min,
                ),
                onSelectedItemChanged: (index) {
                  onValChanged((min + index).toDouble());
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: max - min + 1,
                  builder: (context, index) {
                    int val = min + index;
                    bool isSelected = val == currentVal.toInt();
                    return Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "$val",
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.textWhite
                                  : AppColors.textGrey,
                              fontSize: isSelected ? 40 : 28,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            unit,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryColor
                                  : AppColors.textGrey,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildBottomButton("ДАЛІ", _nextPage),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildBottomButton(String text, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: onTap != null
                ? AppColors.primaryColor
                : AppColors.cardColor,
            foregroundColor: onTap != null ? Colors.black : AppColors.textGrey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: onTap != null ? 8 : 0,
            shadowColor: AppColors.primaryColor.withOpacity(0.5),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// --- HELPER WRAPPERS ---

class _GlassContainer extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;

  const _GlassContainer({
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? AppColors.glassCardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// --- LOADING ANIMATION ---
class _PlanLoadingAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  const _PlanLoadingAnimation({required this.onComplete});

  @override
  State<_PlanLoadingAnimation> createState() => _PlanLoadingAnimationState();
}

class _PlanLoadingAnimationState extends State<_PlanLoadingAnimation> {
  double _progress = 0.0;
  String _statusText = "Аналізуємо дані...";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_progress >= 1.0) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
      } else {
        setState(() {
          _progress += 0.01;
          if (_progress > 0.4) _statusText = "Розрахунок дефіциту...";
          if (_progress > 0.7) _statusText = "Генерація меню...";
          if (_progress > 0.9) _statusText = "Майже готово!";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 12,
                color: AppColors.primaryColor,
                backgroundColor: AppColors.cardColor,
              ),
            ),
            Text(
              "${(_progress * 100).toInt()}%",
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 45,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text(
          _statusText,
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --- SUMMARY AND OTHERS ---
class _OnboardingSummary extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onFinish;

  const _OnboardingSummary({required this.userData, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final weight = userData['weight'] as double;

    final dob = userData['dob'] as DateTime;
    final age = DateTime.now().year - dob.year;
    // Calorie Calculation (Mifflin-St Jeor)
    double bmr =
        10 * weight +
        6.25 * (userData['height'] as double) -
        5 * age +
        (userData['gender'] == 'male' ? 5 : -161);

    // Activity Multiplier
    double activityMultiplier = 1.2;
    if (userData['activity_level'] == "Легка активність") activityMultiplier = 1.375;
    if (userData['activity_level'] == "Середня активність") activityMultiplier = 1.55;
    if (userData['activity_level'] == "Висока активність") activityMultiplier = 1.725;

    double tdee = bmr * activityMultiplier;

    // Time Estimation & Calorie Adjustment
    String estimationText = "";
    final goal = userData['goal'];
    final targetWeight = userData['target_weight'] as double?;
    int daysToGoal = 0;

    if (goal != 'maintain' && targetWeight != null) {
      double diff =
          (targetWeight - weight); // positive if gain, negative if lose
      // Recommended change: 0.5 kg/week
      // 1kg fat = ~7700 kcal. 0.5kg/week = 3850 kcal/week = 550 kcal/day deficiency/surplus
      double weeklyChange = 0.5;
      double dailyCalorieAdjustment = 550;

      if (goal == 'lose') {
        tdee -= dailyCalorieAdjustment;
        userData['weekly_change_goal'] = -weeklyChange;
      } else {
        tdee += dailyCalorieAdjustment;
        userData['weekly_change_goal'] = weeklyChange;
      }

      double weeks = diff.abs() / weeklyChange;
      daysToGoal = (weeks * 7).toInt();
      DateTime estimatedDate = DateTime.now().add(Duration(days: daysToGoal));

      userData['estimated_end_date'] = estimatedDate.toIso8601String();
      estimationText =
          "Досягнення цілі: ${estimatedDate.day}.${estimatedDate.month}.${estimatedDate.year}";
    }

    final calories = tdee.toInt();

    // ... Macros ...
    final protein = (calories * 0.3 / 4).toInt();
    final fat = (calories * 0.3 / 9).toInt();
    final carbs = (calories * 0.4 / 4).toInt();
    final waterL = (weight * 35 / 1000).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Ваш план готовий!",
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          _GlassContainer(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                Text(
                  "Денна ціль калорій",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "$calories ккал",
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Estimation Widget & Graph
                if (goal != 'maintain' &&
                    estimationText.isNotEmpty &&
                    targetWeight != null) ...[
                  const SizedBox(height: 20),

                  // Graph Container
                  Container(
                    height: 220,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.white.withOpacity(0.1),
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (value) => FlLine(
                            color: Colors.white.withOpacity(0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ), // Hide Y numbers but keep grid
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value == weight || value == targetWeight) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      "${value.toInt()} кг",
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value == 0)
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat(
                                        'dd.MM',
                                      ).format(DateTime.now()),
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                if (value == 1)
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('dd.MM').format(
                                        DateTime.parse(
                                          userData['estimated_end_date'],
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                if (value == 0.5)
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      "$daysToGoal днів",
                                      style: TextStyle(
                                        color: AppColors.primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                return const SizedBox.shrink();
                              },
                              interval: 0.5, // To hit 0, 0.5, 1
                              reservedSize: 30,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 1,
                        minY:
                            (weight < targetWeight ? weight : targetWeight) - 5,
                        maxY:
                            (weight > targetWeight ? weight : targetWeight) + 5,
                        lineBarsData: [
                          LineChartBarData(
                            spots: [FlSpot(0, weight), FlSpot(1, targetWeight)],
                            isCurved: true,
                            color: AppColors.primaryColor,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: true),
                            showingIndicators: [0, 1], // Show tooltips for both
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryColor.withOpacity(0.3),
                                  AppColors.primaryColor.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: false, // Static display
                          getTouchedSpotIndicator:
                              (
                                LineChartBarData barData,
                                List<int> spotIndexes,
                              ) {
                                return spotIndexes.map((spotIndex) {
                                  return TouchedSpotIndicatorData(
                                    FlLine(color: Colors.transparent),
                                    FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, percent, barData, index) =>
                                              FlDotCirclePainter(
                                                radius: 6,
                                                color: AppColors.primaryColor,
                                                strokeWidth: 2,
                                                strokeColor: Colors.black,
                                              ),
                                    ),
                                  );
                                }).toList();
                              },
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => Colors.transparent,
                            tooltipPadding: const EdgeInsets.only(bottom: 0),
                            tooltipMargin: 8,
                            getTooltipItems:
                                (List<LineBarSpot> touchedBarSpots) {
                                  return touchedBarSpots.map((barSpot) {
                                    return LineTooltipItem(
                                      "${barSpot.y.toInt()} кг",
                                      TextStyle(
                                        color: AppColors.textWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    );
                                  }).toList();
                                },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 25),
                Container(height: 1, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 25),

                // Macros Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMacroItem("Білки", "${protein} г"),
                    _buildMacroItem("Жири", "${fat} г"),
                    _buildMacroItem("Вуглеводи", "${carbs} г"),
                  ],
                ),
                const SizedBox(height: 25),
                Container(height: 1, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.water_drop, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    Text(
                      "Вода: $waterL л",
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "ПОЧАТИ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}
