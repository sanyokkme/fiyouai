import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_app/screens/basic/register_screen.dart';
import 'dart:async';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentStep = 0;
  bool _isNameValid = false;

  // Об'єкт для збору даних
  final Map<String, dynamic> userData = {
    "source": "",
    "name": "",
    "goal": "lose",
    "gender": "male",
    "dob": DateTime(2000, 1, 1),
    "activity": "Сидячий",
    "height": 170.0,
    "weight": 70.0,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
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
      body: SafeArea(
        child: Column(
          children: [
            // Індикатор прогресу зверху
            Padding(
              padding: const EdgeInsets.all(20),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 10,
                color: AppColors.primaryColor,
                backgroundColor: AppColors.backgroundDarkAccent,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildSourceStep(),
                  _buildNameStep(),
                  _buildGoalStep(),
                  _buildGenderStep(),
                  _buildDOBStep(),
                  _buildActivityStep(),
                  _buildHeightStep(),
                  _buildWeightStep(),
                  _buildLoadingPlanStep(),
                  _buildSummaryStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- КРОКИ ---

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
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Як вас звати?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Це допоможе нам персоналізувати ваш досвід",
            style: TextStyle(color: Colors.white60, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            textAlign: TextAlign.center,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: "Введіть ім'я",
              hintStyle: const TextStyle(color: Colors.white24),
              helperText: _isNameValid ? "✓ Чудове ім'я!" : "Мінімум 2 символи",
              helperStyle: TextStyle(
                color: _isNameValid ? AppColors.primaryColor : Colors.white38,
                fontSize: 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _validateName,
          ),
          const SizedBox(height: 50),
          _buildNextButton(
            _isNameValid ? _nextPage : null,
            isEnabled: _isNameValid,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return _buildSelectionStep(
      "Ваша ціль?",
      ["Скинути вагу", "Утримати вагу", "Набрати вагу"],
      (val) {
        // Normalize Ukrainian text to English for database
        if (val == "Скинути вагу") {
          userData['goal'] = "lose";
        } else if (val == "Набрати вагу") {
          userData['goal'] = "gain";
        } else if (val == "Утримати вагу") {
          userData['goal'] = "maintain";
        }
        _nextPage();
      },
    );
  }

  Widget _buildGenderStep() {
    return _buildSelectionStep("Ваша стать?", ["Чоловік", "Жінка"], (val) {
      // Normalize Ukrainian text to English for database
      if (val == "Чоловік") {
        userData['gender'] = "male";
      } else if (val == "Жінка") {
        userData['gender'] = "female";
      }
      _nextPage();
    });
  }

  Widget _buildDOBStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Ваша дата народження?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 250,
          child: CupertinoTheme(
            data: const CupertinoThemeData(
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: userData['dob'],
              maximumYear: DateTime.now().year,
              onDateTimeChanged: (val) => userData['dob'] = val,
            ),
          ),
        ),
        const SizedBox(height: 40),
        _buildNextButton(_nextPage),
      ],
    );
  }

  Widget _buildActivityStep() {
    return _buildSelectionStep(
      "Ваш стиль життя",
      [
        "Сидячий",
        "Легка активність",
        "Середня активність",
        "Висока активність",
      ],
      (val) {
        userData['activity'] = val;
        _nextPage();
      },
    );
  }

  Widget _buildHeightStep() {
    return _buildSliderStep("Ваш ріст", 100, 230, "см", "height");
  }

  Widget _buildWeightStep() {
    return _buildSliderStep("Ваша вага", 30, 200, "кг", "weight");
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

  // --- ДОПОМІЖНІ ВІДЖЕТИ ---

  Widget _buildSelectionStep(
    String title,
    List<String> options,
    Function(String) onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          ...options.map(
            (opt) => Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _InteractiveButton(
                text: opt,
                onPressed: () => onSelect(opt),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderStep(
    String title,
    double min,
    double max,
    String unit,
    String key,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          "${userData[key].toInt()} $unit",
          style: const TextStyle(
            color: AppColors.primaryColor,
            fontSize: 55,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Slider(
            value: userData[key],
            min: min,
            max: max,
            activeColor: AppColors.primaryColor,
            inactiveColor: Colors.white12,
            onChanged: (v) => setState(() => userData[key] = v),
          ),
        ),
        const SizedBox(height: 50),
        _buildNextButton(_nextPage),
      ],
    );
  }

  Widget _buildNextButton(VoidCallback? onTap, {bool isEnabled = true}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 200,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? AppColors.primaryColor
              : AppColors.primaryColor.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: isEnabled ? 4 : 0,
        ),
        onPressed: onTap,
        child: Text(
          "ДАЛІ",
          style: TextStyle(
            color: isEnabled ? Colors.black : Colors.black38,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// --- АНІМАЦІЯ ЗАВАНТАЖЕННЯ ПЛАНУ ---

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
                backgroundColor: Colors.white10,
              ),
            ),
            Text(
              "${(_progress * 100).toInt()}%",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 45,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text(
          _statusText,
          style: const TextStyle(
            color: AppColors.primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 40),
        _buildBenefitItem("Персональний розрахунок калорій"),
        _buildBenefitItem("Аналіз страв за фотографією"),
        _buildBenefitItem("Відстеження водного балансу"),
      ],
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 50),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// --- ФІНАЛЬНИЙ ПІДСУМОК ПЕРЕД РЕЄСТРАЦІЄЮ ---

class _OnboardingSummary extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onFinish;

  const _OnboardingSummary({required this.userData, required this.onFinish});

  // Розрахунок віку з дати народження
  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  // Розрахунок BMR (Basal Metabolic Rate) за формулою Mifflin-St Jeor
  double _calculateBMR() {
    final weight = userData['weight'] as double;
    final height = userData['height'] as double;
    final age = _calculateAge(userData['dob'] as DateTime);
    final isMale = userData['gender'] == 'male';

    final bmr = isMale
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;

    print(
      '📊 BMR: $bmr (вага: $weight, ріст: $height, вік: $age, стать: ${isMale ? "чоловік" : "жінка"})',
    );
    return bmr;
  }

  // Розрахунок TDEE (Total Daily Energy Expenditure)
  double _calculateTDEE() {
    final bmr = _calculateBMR();
    final activity = userData['activity'] as String;

    double multiplier;
    switch (activity) {
      case 'Сидячий':
        multiplier = 1.2;
        break;
      case 'Легка активність':
        multiplier = 1.375;
        break;
      case 'Середня активність':
        multiplier = 1.55;
        break;
      case 'Висока активність':
        multiplier = 1.725;
        break;
      default:
        print('⚠️ Невідомий рівень активності: $activity, використовую 1.2');
        multiplier = 1.2;
    }

    final tdee = bmr * multiplier;
    print('📊 TDEE: $tdee (BMR: $bmr × активність: $multiplier)');
    return tdee;
  }

  // Розрахунок цільової калорійності на основі мети
  double _calculateTargetCalories() {
    final tdee = _calculateTDEE();
    final goal = userData['goal'] as String;

    print('🎯 Ціль користувача: $goal');

    double target;
    switch (goal) {
      case 'lose':
        target = tdee - 500; // Дефіцит 500 ккал для схуднення
        print('📉 Схуднення: TDEE $tdee - 500 = $target');
        break;
      case 'gain':
        target = tdee + 500; // Профіцит 500 ккал для набору (як на бекенді!)
        print('📈 Набір: TDEE $tdee + 500 = $target');
        break;
      case 'maintain':
      default:
        target = tdee; // Підтримка ваги
        print('➡️ Підтримка: TDEE $tdee');
    }

    return target;
  }

  // Розрахунок макронутрієнтів (30/30/40 як на бекенді)
  Map<String, double> _calculateMacros() {
    final targetCalories = _calculateTargetCalories();

    // Backend formula: 30% protein, 30% fat, 40% carbs
    final proteinGrams = (targetCalories * 0.3) / 4;
    final fatGrams = (targetCalories * 0.3) / 9;
    final carbGrams = (targetCalories * 0.4) / 4;

    // Логування для перевірки
    print('=== ONBOARDING MACRO CALCULATION ===');
    print('Target Calories: $targetCalories');
    print('Protein: ${proteinGrams.toInt()}g (30% калорій)');
    print('Fat: ${fatGrams.toInt()}g (30% калорій)');
    print('Carbs: ${carbGrams.toInt()}g (40% калорій)');
    print('====================================');

    return {
      'calories': targetCalories,
      'protein': proteinGrams,
      'fat': fatGrams,
      'carbs': carbGrams,
    };
  }

  @override
  Widget build(BuildContext context) {
    final macros = _calculateMacros();
    final calories = macros['calories']!.round();
    final protein = macros['protein']!.round();
    final fat = macros['fat']!.round();
    final carbs = macros['carbs']!.round();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            "Ваша персональна ціль готова",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Ось ваш індивідуальний план харчування",
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 40),

          // Калорії - велика карта
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor.withValues(alpha: 0.15),
                  AppColors.primaryColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  "Денна норма",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "$calories",
                      style: const TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(
                        "ккал",
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Макронутрієнти
          const Text(
            "Макронутрієнти",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildMacroRow(protein, fat, carbs),

          const SizedBox(height: 32),

          // Водний баланс
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Водний баланс",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${((userData['weight'] as double) * 0.03).toStringAsFixed(1)} л/день",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Поради
          const Text(
            "Швидкі поради",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildAdvice("Фотографуйте страви перед їдою"),
          _buildAdvice("Пийте воду протягом дня"),
          _buildAdvice("Додавайте овочі до кожного прийому"),

          const SizedBox(height: 40),

          // Кнопка
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                "ПРОДОВЖИТИ",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(int protein, int fat, int carbs) {
    return Row(
      children: [
        Expanded(
          child: _buildSimpleMacroCard("Білки", protein, Icons.egg_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildSimpleMacroCard("Жири", fat, Icons.opacity)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSimpleMacroCard(
            "Вуглеводи",
            carbs,
            Icons.rice_bowl_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleMacroCard(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 24),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "$value",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                " г",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvice(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// --- ІНТЕРАКТИВНА КНОПКА З АНІМАЦІЄЮ ---

class _InteractiveButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const _InteractiveButton({required this.text, required this.onPressed});

  @override
  State<_InteractiveButton> createState() => _InteractiveButtonState();
}

class _InteractiveButtonState extends State<_InteractiveButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _isPressed
                ? AppColors.primaryColor
                : AppColors.primaryColor.withValues(alpha: 0.6),
            width: _isPressed ? 2.0 : 1.5,
          ),
          color: _isPressed
              ? AppColors.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            widget.text,
            style: TextStyle(
              color: _isPressed ? AppColors.primaryColor : Colors.white,
              fontSize: 18,
              fontWeight: _isPressed ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
