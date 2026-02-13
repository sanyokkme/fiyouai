import 'package:flutter/material.dart';
import 'package:flutter_app/constants/app_colors.dart';
import 'package:flutter_app/services/auth_service.dart';

class GoalSpeedSheet extends StatefulWidget {
  final double currentSpeed;
  final bool isGain; // true if gaining weight, false if losing
  final Function(double) onSpeedUpdated;

  const GoalSpeedSheet({
    super.key,
    required this.currentSpeed,
    required this.isGain,
    required this.onSpeedUpdated,
  });

  @override
  State<GoalSpeedSheet> createState() => _GoalSpeedSheetState();
}

class _GoalSpeedSheetState extends State<GoalSpeedSheet> {
  late double _selectedSpeed;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSpeed = widget.currentSpeed.abs();
    // Default to 0.5 if 0 or null
    if (_selectedSpeed == 0) _selectedSpeed = 0.5;
  }

  Future<void> _saveSpeed() async {
    setState(() => _isLoading = true);
    try {
      // If losing weight, speed should be negative in backend (usually)
      // But based on previous logic, Profile uses negative for lose?
      // Let's check: "weekly_change_goal: Optional[float] = None # e.g. -0.5"
      // Yes, negative for lose.
      double finalValue = widget.isGain ? _selectedSpeed : -_selectedSpeed;

      await AuthService.updateProfile('weekly_change_goal', finalValue);
      widget.onSpeedUpdated(finalValue);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error updating speed: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Помилка: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: AppColors.cardColor),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Швидкість зміни ваги",
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildOption(
            value: 0.25,
            icon: "🐢",
            title: "Спокійний",
            subtitle: "0.25 кг / тиждень",
            description:
                "Мінімальний стрес для організму. Найлегше дотримуватись.",
          ),
          const SizedBox(height: 12),
          _buildOption(
            value: 0.5,
            icon: "🚶",
            title: "Звичайний",
            subtitle: "0.5 кг / тиждень",
            description:
                "Рекомендований темп. Баланс між результатом і зусиллями.",
          ),
          const SizedBox(height: 12),
          _buildOption(
            value: 1.0,
            icon: "🏃",
            title: "Інтенсивний",
            subtitle: "1.0 кг / тиждень",
            description:
                "Швидкий результат, але вимагає суворої дієти та дисципліни.",
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveSpeed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      "ЗБЕРЕГТИ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption({
    required double value,
    required String icon,
    required String title,
    required String subtitle,
    required String description,
  }) {
    bool isSelected = _selectedSpeed == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedSpeed = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withOpacity(0.15)
              : AppColors.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primaryColor
                              : AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primaryColor
                              : AppColors.textWhite,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
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
