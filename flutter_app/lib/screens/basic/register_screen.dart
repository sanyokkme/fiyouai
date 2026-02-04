import 'package:flutter/material.dart';
import 'package:flutter_app/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  // Дані, зібрані під час опитування (Onboarding)
  final Map<String, dynamic> onboardingData;

  const RegisterScreen({super.key, required this.onboardingData});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();

  // Контролери для полів вводу
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    // Обов'язково звільняємо пам'ять при закритті екрана
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool _isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleRegister() async {
    // Закриваємо клавіатуру перед початком
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

  
    // Валідація полів
    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError("Будь ласка, заповніть усі поля");
      return;
    }
    if (!_isEmailValid(email)) {
      _showError("Введіть коректний Email");
      return;
    }
    if (password != confirmPassword) {
      _showError("Паролі не збігаються");
      return;
    }
    if (password.length < 6) {
      _showError("Пароль має бути не менше 6 символів");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Готуємо дані для відправки
      final Map<String, dynamic> readyOnboardingData = Map.from(
        widget.onboardingData,
      );

      // Конвертуємо DateTime у рядок ISO8601 для бекенду
      if (readyOnboardingData['dob'] != null &&
          readyOnboardingData['dob'] is DateTime) {
        readyOnboardingData['dob'] = (readyOnboardingData['dob'] as DateTime)
            .toIso8601String();
      }

      // Викликаємо сервіс реєстрації
      final result = await _authService.register(
        email,
        password,
        onboardingData: readyOnboardingData,
      );

      if (!mounted) return;

      if (result['user_id'] != null) {
        // Успішна реєстрація: переходимо на головний екран, видаляючи всю історію
        await Future.delayed(const Duration(milliseconds: 800));
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      // Обробка помилок (наприклад, "Користувач вже існує")
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Останній крок',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Створіть акаунт, щоб зберегти ваш персональний план харчування.',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 40),

                _buildTextField(
                  controller: _emailController,
                  label: "Email",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: _passwordController,
                  label: "Пароль",
                  icon: Icons.lock_outline,
                  obscureText: _obscureText,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                      color: Colors.greenAccent,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: _confirmPasswordController,
                  label: "Підтвердіть пароль",
                  icon: Icons.lock_reset_outlined,
                  obscureText: _obscureText,
                ),

                const SizedBox(height: 40),

                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "ЗБЕРЕГТИ ПЛАН",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: !_isLoading, // Поле блокується тільки під час завантаження
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.greenAccent),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}
