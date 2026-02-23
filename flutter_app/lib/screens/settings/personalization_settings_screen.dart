import 'package:flutter/material.dart';
import 'package:flutter_app/services/theme_service.dart';
import '../../constants/app_colors.dart';

class PersonalizationSettingsScreen extends StatefulWidget {
  const PersonalizationSettingsScreen({super.key});

  @override
  State<PersonalizationSettingsScreen> createState() =>
      _PersonalizationSettingsScreenState();
}

class _PersonalizationSettingsScreenState
    extends State<PersonalizationSettingsScreen> {
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
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Тема оформлення',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                        ),
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

                      // --- COLOR SELECTION ---
                      Text(
                        "Акцентний колір",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ValueListenableBuilder<Color>(
                        valueListenable: ThemeService().primaryColorNotifier,
                        builder: (context, currentColor, _) {
                          return Container(
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 25),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: ThemeService.availableColors.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 15),
                              itemBuilder: (context, index) {
                                final color =
                                    ThemeService.availableColors[index];
                                final isSelected =
                                    color.value == currentColor.value;
                                return GestureDetector(
                                  onTap: () =>
                                      ThemeService().setPrimaryColor(color),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: AppColors.textWhite,
                                              width: 3,
                                            )
                                          : null,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            color: AppColors.textWhite,
                                            size: 30,
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),

                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeService().themeModeNotifier,
                        builder: (context, themeMode, _) {
                          String themeText = '';
                          IconData themeIcon = Icons.brightness_auto;
                          switch (themeMode) {
                            case ThemeMode.system:
                              themeText = 'Системна';
                              themeIcon = Icons.brightness_auto;
                            case ThemeMode.light:
                              themeText = 'Світла';
                              themeIcon = Icons.light_mode;
                            case ThemeMode.dark:
                              themeText = 'Темна';
                              themeIcon = Icons.dark_mode;
                          }
                          return _buildOptionTile(
                            title: 'Оформлення',
                            subtitle: themeText,
                            icon: themeIcon,
                            onTap: () {
                              _showThemeModeDialog(themeMode);
                            },
                          );
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

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
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
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.primaryColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemeModeDialog(ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Оформлення', style: TextStyle(color: AppColors.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('Системна', ThemeMode.system, currentMode),
            _buildThemeOption('Світла', ThemeMode.light, currentMode),
            _buildThemeOption('Темна', ThemeMode.dark, currentMode),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    String title,
    ThemeMode mode,
    ThemeMode currentMode,
  ) {
    return RadioListTile<ThemeMode>(
      title: Text(title, style: TextStyle(color: AppColors.textWhite)),
      value: mode,
      groupValue: currentMode,
      activeColor: AppColors.primaryColor,
      onChanged: (value) {
        ThemeService().setThemeMode(value!);
        Navigator.pop(context);
      },
    );
  }
}
