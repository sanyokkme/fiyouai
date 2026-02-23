import 'package:flutter/material.dart';
import '../../services/home_layout_service.dart';
import '../../constants/app_colors.dart';

class HomeLayoutSettingsScreen extends StatefulWidget {
  const HomeLayoutSettingsScreen({super.key});

  @override
  State<HomeLayoutSettingsScreen> createState() =>
      _HomeLayoutSettingsScreenState();
}

class _HomeLayoutSettingsScreenState extends State<HomeLayoutSettingsScreen> {
  late List<String> _currentOrder;

  final Map<String, String> _widgetNames = {
    'dashboard_stats': 'Калорії та БЖВ',
    'mood_tracker': 'Настрій',
    'water_tracker': 'Водний баланс',
    'sleep_calculator': 'Сон',
    'vitamins_section': 'Вітаміни',
    'activity_timeline': 'Активність сьогодні',
  };

  final Map<String, IconData> _widgetIcons = {
    'dashboard_stats': Icons.pie_chart_outline,
    'mood_tracker': Icons.mood,
    'water_tracker': Icons.water_drop_outlined,
    'sleep_calculator': Icons.nightlight_round,
    'vitamins_section': Icons.medication_outlined,
    'activity_timeline': Icons.timeline,
  };

  @override
  void initState() {
    super.initState();
    _currentOrder = List.from(HomeLayoutService().orderNotifier.value);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _currentOrder.removeAt(oldIndex);
      _currentOrder.insert(newIndex, item);
    });
    // Зберігаємо одразу
    HomeLayoutService().saveOrder(_currentOrder);
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
                    Expanded(
                      child: Text(
                        'Макет екрана',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 10,
                ),
                child: Text(
                  'Перетягніть віджети, щоб змінити їхній порядок на головному екрані.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  onReorder: _onReorder,
                  children: _currentOrder.map((key) {
                    return Container(
                      key: ValueKey(key),
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _widgetIcons[key] ?? Icons.widgets,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        title: Text(
                          _widgetNames[key] ?? key,
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        trailing: Icon(
                          Icons.drag_handle,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
