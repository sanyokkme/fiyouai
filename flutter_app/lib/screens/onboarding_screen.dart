import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui'; // Needed for ImageFilter
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
    if (_currentStep == _totalSteps - 2 || _currentStep == _totalSteps - 1) {
      return const SizedBox.shrink();
    }

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
          if (val == "Скинути вагу") {
            userData['goal'] = "lose";
          } else if (val == "Набрати вагу")
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
            separatorBuilder: (_, _) => const SizedBox(height: 15),
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
class _OnboardingSummary extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onFinish;

  const _OnboardingSummary({required this.userData, required this.onFinish});

  @override
  State<_OnboardingSummary> createState() => _OnboardingSummaryState();
}

class _OnboardingSummaryState extends State<_OnboardingSummary>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    // Create 5 staggered animations for different sections
    _controllers = List.generate(
      5,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _fadeAnimations = _controllers
        .map(
          (controller) =>
              CurvedAnimation(parent: controller, curve: Curves.easeOut),
        )
        .toList();

    _slideAnimations = _controllers
        .map(
          (controller) => Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut)),
        )
        .toList();

    // Start animations with stagger
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weight = widget.userData['weight'] as double;
    final height = widget.userData['height'] as double;

    final dob = widget.userData['dob'] as DateTime;
    final age = DateTime.now().year - dob.year;
    final gender = widget.userData['gender'];
    final activityLevel = widget.userData['activity_level'];

    // Calorie Calculation (Mifflin-St Jeor)
    double bmr =
        10 * weight + 6.25 * height - 5 * age + (gender == 'male' ? 5 : -161);

    // Activity Multiplier
    double activityMultiplier = 1.2;
    if (activityLevel == "Легка активність") activityMultiplier = 1.375;
    if (activityLevel == "Середня активність") activityMultiplier = 1.55;
    if (activityLevel == "Висока активність") activityMultiplier = 1.725;

    double tdee = bmr * activityMultiplier;

    // Time Estimation & Calorie Adjustment
    final goal = widget.userData['goal'];
    final targetWeight = widget.userData['target_weight'] as double?;
    int daysToGoal = 0;
    DateTime? estimatedDate;
    double dailyCalorieAdjustment = 0;

    if (goal != 'maintain' && targetWeight != null) {
      double diff = (targetWeight - weight);
      double weeklyChange = 0.5;
      dailyCalorieAdjustment = 550;

      if (goal == 'lose') {
        tdee -= dailyCalorieAdjustment;
        widget.userData['weekly_change_goal'] = -weeklyChange;
      } else {
        tdee += dailyCalorieAdjustment;
        widget.userData['weekly_change_goal'] = weeklyChange;
      }

      double weeks = diff.abs() / weeklyChange;
      daysToGoal = (weeks * 7).toInt();
      estimatedDate = DateTime.now().add(Duration(days: daysToGoal));
      widget.userData['estimated_end_date'] = estimatedDate.toIso8601String();
    }

    final calories = tdee.toInt();
    final protein = (calories * 0.3 / 4).toInt();
    final fat = (calories * 0.3 / 9).toInt();
    final carbs = (calories * 0.4 / 4).toInt();
    final waterL = (weight * 35 / 1000).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title with animation
          FadeTransition(
            opacity: _fadeAnimations[0],
            child: SlideTransition(
              position: _slideAnimations[0],
              child: Column(
                children: [
                  Text("🎉", style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  Text(
                    "Ваш план готовий!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Date achievement with animation
          if (goal != 'maintain' && estimatedDate != null)
            FadeTransition(
              opacity: _fadeAnimations[1],
              child: SlideTransition(
                position: _slideAnimations[1],
                child: _GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: AppColors.primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Ціль буде досягнута",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd.MM.yyyy').format(estimatedDate),
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "через $daysToGoal днів",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (goal != 'maintain' && estimatedDate != null)
            const SizedBox(height: 24),

          // Calories section with animation
          FadeTransition(
            opacity: _fadeAnimations[2],
            child: SlideTransition(
              position: _slideAnimations[2],
              child: _GlassContainer(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("🔥", style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(
                          "Денна норма калорій",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "$calories",
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Text(
                      "ккал",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Macros with circular progress
          FadeTransition(
            opacity: _fadeAnimations[3],
            child: SlideTransition(
              position: _slideAnimations[3],
              child: _GlassContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("💪", style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(
                          "Макронутрієнти",
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCircularMacro(
                          "Білки",
                          protein,
                          const Color(0xFFFF6B9D),
                          0.3,
                        ),
                        _buildCircularMacro(
                          "Жири",
                          fat,
                          const Color(0xFFFFA726),
                          0.3,
                        ),
                        _buildCircularMacro(
                          "Вуглеводи",
                          carbs,
                          const Color(0xFF42A5F5),
                          0.4,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("💧", style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Text(
                            "Вода: ",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "$waterL л",
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Calculation details with animation
          FadeTransition(
            opacity: _fadeAnimations[4],
            child: SlideTransition(
              position: _slideAnimations[4],
              child: _GlassContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("📊", style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(
                          "Деталі розрахунку",
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildCalcRow(
                      "Базовий метаболізм",
                      "${bmr.toInt()} ккал",
                      Icons.favorite,
                    ),
                    const SizedBox(height: 12),
                    _buildCalcRow(
                      "Коефіцієнт активності",
                      "×${activityMultiplier.toStringAsFixed(2)}",
                      Icons.directions_run,
                    ),
                    const SizedBox(height: 12),
                    _buildCalcRow(
                      "TDEE",
                      "${(bmr * activityMultiplier).toInt()} ккал",
                      Icons.local_fire_department,
                    ),
                    if (goal != 'maintain' && dailyCalorieAdjustment > 0) ...[
                      const SizedBox(height: 12),
                      _buildCalcRow(
                        goal == 'lose' ? "Дефіцит" : "Профіцит",
                        "${goal == 'lose' ? '-' : '+'}${dailyCalorieAdjustment.toInt()} ккал",
                        goal == 'lose'
                            ? Icons.trending_down
                            : Icons.trending_up,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Big finish button
          Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryColor, AppColors.brightPrimaryColor],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: widget.onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "ПОЧАТИ ПОДОРОЖ",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_forward, color: Colors.black, size: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCircularMacro(
    String label,
    int grams,
    Color color,
    double percentage,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 8,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$grams",
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "г",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildCalcRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
