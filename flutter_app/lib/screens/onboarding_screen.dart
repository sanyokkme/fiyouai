import 'package:flutter/material.dart';
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
  int _currentStep = 0;

  // Об'єкт для збору даних
  final Map<String, dynamic> userData = {
    "source": "",
    "name": "",
    "goal": "lose",
    "gender": "Чоловік",
    "dob": DateTime(2000, 1, 1),
    "activity": "Сидячий",
    "height": 170.0,
    "weight": 70.0,
  };

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // Індикатор прогресу зверху
            Padding(
              padding: const EdgeInsets.all(20),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 10,
                color: Colors.greenAccent,
                backgroundColor: Colors.white10,
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
          const SizedBox(height: 30),
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 20),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "Введіть ім'я",
              hintStyle: const TextStyle(color: Colors.white24),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.greenAccent.withOpacity(0.5),
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.greenAccent),
              ),
            ),
            onChanged: (v) => userData['name'] = v,
          ),
          const SizedBox(height: 50),
          _buildNextButton(_nextPage),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return _buildSelectionStep(
      "Ваша ціль?",
      ["Скинути вагу", "Утримати вагу", "Набрати вагу"],
      (val) {
        userData['goal'] = val;
        _nextPage();
      },
    );
  }

  Widget _buildGenderStep() {
    return _buildSelectionStep("Ваша стать?", ["Чоловік", "Жінка"], (val) {
      userData['gender'] = val;
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
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.greenAccent,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => onSelect(opt),
                  child: Text(
                    opt,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
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
            color: Colors.greenAccent,
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
            activeColor: Colors.greenAccent,
            inactiveColor: Colors.white12,
            onChanged: (v) => setState(() => userData[key] = v),
          ),
        ),
        const SizedBox(height: 50),
        _buildNextButton(_nextPage),
      ],
    );
  }

  Widget _buildNextButton(VoidCallback onTap) {
    return SizedBox(
      width: 200,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onTap,
        child: const Text(
          "ДАЛІ",
          style: TextStyle(
            color: Colors.black,
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
                color: Colors.greenAccent,
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
            color: Colors.greenAccent,
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
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const Text(
            "Ваш добовий ліміт",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),

          // Кругова діаграма лімітів (БЖВ)
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: 0.7,
                  strokeWidth: 15,
                  color: Colors.blueAccent.withOpacity(0.8),
                  backgroundColor: Colors.white10,
                ),
              ),
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: 0.5,
                  strokeWidth: 15,
                  color: Colors.orangeAccent.withOpacity(0.8),
                  backgroundColor: Colors.transparent,
                ),
              ),
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: 0.4,
                  strokeWidth: 15,
                  color: Colors.purpleAccent.withOpacity(0.8),
                  backgroundColor: Colors.transparent,
                ),
              ),
              const Icon(Icons.bolt, color: Colors.greenAccent, size: 40),
            ],
          ),

          const SizedBox(height: 30),
          _buildMacroRow(),
          const SizedBox(height: 40),

          const Text(
            "Водний баланс: 2.1 л / день",
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),

          const Text(
            "5 порад для початку:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _advice("Пийте склянку води відразу після пробудження."),
          _advice("Намагайтеся заповнювати половину тарілки овочами."),
          _advice("Фотографуйте їжу до того, як почнете їсти."),
          _advice("Робіть перерву на прогулянку кожні 2 години."),
          _advice("Не їжте за 3 години до сну для кращого відновлення."),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "СТВОРИТИ АККАУНТ",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _macroItem("Білки", Colors.blueAccent),
        _macroItem("Жири", Colors.orangeAccent),
        _macroItem("Вуглеводи", Colors.purpleAccent),
      ],
    );
  }

  Widget _macroItem(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _advice(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "• ",
            style: TextStyle(color: Colors.greenAccent, fontSize: 20),
          ),
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
