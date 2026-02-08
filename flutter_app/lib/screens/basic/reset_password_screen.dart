import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Новий пароль",
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: controller,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Введіть новий пароль",
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                    onPressed: () {
                      // Тут логіка виклику AuthService.updateUserPassword
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text("ОНОВИТИ"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
