import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _waterReminders = true;
  bool _mealReminders = true;
  bool _vitaminReminders = true;
  bool _exerciseReminders = false;

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
                      'Нагадування',
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

                      _buildSwitchTile(
                        title: 'Нагадування про воду',
                        subtitle: 'Отримуйте нагадування випити води',
                        icon: Icons.water_drop_outlined,
                        value: _waterReminders,
                        onChanged: (val) =>
                            setState(() => _waterReminders = val),
                      ),

                      _buildSwitchTile(
                        title: 'Нагадування про прийом їжі',
                        subtitle: 'Нагадування про сніданок, обід та вечерю',
                        icon: Icons.restaurant_outlined,
                        value: _mealReminders,
                        onChanged: (val) =>
                            setState(() => _mealReminders = val),
                      ),

                      _buildSwitchTile(
                        title: 'Нагадування про вітаміни',
                        subtitle: 'Нагадування прийняти вітаміни вчасно',
                        icon: Icons.medication_outlined,
                        value: _vitaminReminders,
                        onChanged: (val) =>
                            setState(() => _vitaminReminders = val),
                      ),

                      _buildSwitchTile(
                        title: 'Нагадування про тренування',
                        subtitle: 'Мотивація для фізичних вправ',
                        icon: Icons.fitness_center_outlined,
                        value: _exerciseReminders,
                        onChanged: (val) =>
                            setState(() => _exerciseReminders = val),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.cardColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }
}
