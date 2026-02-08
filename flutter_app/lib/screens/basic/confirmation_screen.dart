import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class ConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> onboardingData;

  const ConfirmationScreen({super.key, required this.onboardingData});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isPressed = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onConfirmationComplete();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onConfirmationComplete() async {
    if (!mounted) return;

    setState(() => _isCompleted = true);

    // Wait 1.5 seconds before navigating
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Navigate with fade transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          // Import home screen dynamically or use named route
          return FadeTransition(
            opacity: animation,
            child: Navigator(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => const SizedBox(), // Placeholder
                );
              },
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );

    // Fallback to named route
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _onPressStart() {
    if (_isCompleted) return;
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _onPressEnd() {
    if (_isCompleted) return;
    setState(() => _isPressed = false);
    _animationController.reset();
  }

  String _getGoalText() {
    final goal = widget.onboardingData['goal']?.toString().toLowerCase() ?? '';
    if (goal.contains('lose') ||
        goal.contains('схуднути') ||
        goal.contains('скинути')) {
      return 'Скинути вагу';
    } else if (goal.contains('gain') || goal.contains('набрати')) {
      return 'Набрати вагу';
    } else if (goal.contains('maintain') || goal.contains('утримувати')) {
      return 'Утримувати вагу';
    }
    return 'Досягти мети';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Stack(
            children: [
              // Removed radial gradient for cleaner look

              // Main content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _isCompleted
                    ? _buildCompletionMessage()
                    : _buildConfirmationContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationContent() {
    return Center(
      key: const ValueKey('confirmation'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Title
          const Text(
            'Ваше рішення',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),

          // Goal text
          Text(
            _getGoalText(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryColor,
            ),
          ),

          const SizedBox(height: 60),

          // Fingerprint with animation
          GestureDetector(
            onLongPressStart: (_) => _onPressStart(),
            onLongPressEnd: (_) => _onPressEnd(),
            onLongPressCancel: () => _onPressEnd(),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Border circle
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),

                    // Progress ring
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: _animationController.value,
                        strokeWidth: 3,
                        color: AppColors.primaryColor,
                        backgroundColor: Colors.transparent,
                      ),
                    ),

                    // Fingerprint icon
                    Icon(
                      Icons.fingerprint,
                      size: 100,
                      color: _isPressed
                          ? AppColors.primaryColor
                          : Colors.white70,
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 40),

          // Instruction text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isPressed
                  ? 'Тримайте...'
                  : 'Натисніть і утримуйте\nщоб підтвердити',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _isPressed ? AppColors.primaryColor : Colors.white60,
                fontWeight: _isPressed ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildCompletionMessage() {
    return Center(
      key: const ValueKey('completion'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon
            const Icon(
              Icons.check_circle,
              size: 100,
              color: AppColors.primaryColor,
            ),
            const SizedBox(height: 30),

            // Completion message
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Вітаємо в ',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: 'FiYouAI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
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
}
