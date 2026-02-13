import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'change_password_screen.dart';

import '../../services/auth_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);

    try {
      final userId = await AuthService.getStoredUserId();
      if (userId == null) throw Exception('User ID not found');

      // Використовуємо централізований метод в AuthService
      await AuthService.deleteAccount(userId);

      if (!mounted) return;

      // Переходимо на welcome screen і очищаємо навігацію
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/welcome', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Акаунт успішно видалено.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Закриваємо діалог

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Помилка: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(
                      'Акаунт',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      _buildOptionTile(
                        context,
                        title: 'Змінити пароль',
                        icon: Icons.lock_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),
                      Divider(color: AppColors.cardColor),
                      const SizedBox(height: 30),

                      _buildOptionTile(
                        context,
                        title: 'Видалити обліковий запис',
                        icon: Icons.delete_outline,
                        iconColor: Colors.redAccent,
                        titleColor: Colors.redAccent,
                        onTap: () {
                          _showDeleteConfirmation(context);
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildOptionTile(
                        context,
                        title: 'Вийти з акаунту',
                        icon: Icons.logout,
                        iconColor: AppColors.iconColor,
                        titleColor: AppColors.textWhite,
                        onTap: () async {
                          await AuthService.logout();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/welcome',
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.cardColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? AppColors.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? AppColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: iconColor ?? AppColors.primaryColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible:
          !_isDeleting, // Забороняємо закривати під час видалення
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Видалити обліковий запис?',
              style: TextStyle(color: AppColors.textWhite),
            ),
            content: _isDeleting
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.redAccent),
                          SizedBox(height: 16),
                          Text(
                            'Видалення...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    'Ця дія незворотна. Всі ваші дані (профіль, фото) будуть назавжди видалені.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
            actions: _isDeleting
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Скасувати',
                        style: TextStyle(color: AppColors.textWhite),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Start deletion and update dialog state
                        setState(() => _isDeleting = true);
                        // Call the main delete function
                        _deleteAccount();
                      },
                      child: const Text(
                        'Видалити',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }
}
