import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import '../services/data_manager.dart'; // Імпорт менеджера

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  Map<String, dynamic>? _aiData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTipsFromCache();
  }

  Future<void> _loadTipsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();

    if (userId != null) {
      // 1. Читаємо те, що підготував DataManager
      final cachedTips = prefs.getString('${DataManager.keyTips}_$userId');

      if (cachedTips != null) {
        if (mounted) {
          setState(() {
            _aiData = jsonDecode(cachedTips);
            _isLoading = false;
          });
        }
      } else {
        // Якщо раптом кешу немає (перший запуск) - спробуємо запустити менеджер
        await DataManager().prefetchAllData();
        _loadTipsFromCache(); // Рекурсивна спроба
        return;
      }
    }

    // 2. Позначаємо як прочитані (щоб при наступному запуску додатку згенерувались нові)
    DataManager().markTipsAsViewed();
  }

  // --- SKELETON LOADER (Той самий, що був) ---
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.textGrey.withValues(alpha: 0.1),
      highlightColor: AppColors.textGrey.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: _isLoading
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                      child: Row(
                        children: [
                          Text(
                            'AI Поради',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildSkeleton()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                      child: Row(
                        children: [
                          Text(
                            'AI Поради',
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
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: 30),
                            Text(
                              "Персональні рекомендації",
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            // Виводимо список порад
                            ...(_aiData?['tips'] as List? ?? []).map(
                              (tip) => _buildTipCard(tip),
                            ),

                            // Повідомлення для користувача
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                "Нові поради з'являться при наступному вході в додаток",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
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

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withValues(alpha: 0.2),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.primaryColor, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              _aiData?['summary'] ?? "Аналізуємо ваш раціон...",
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(dynamic tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.glassCardColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tip['title'] ?? "",
            style: TextStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tip['text'] ?? "",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
