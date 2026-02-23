import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import '../services/data_manager.dart';

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
      final cachedTips = prefs.getString('${DataManager.keyTips}_$userId');

      if (cachedTips != null) {
        if (mounted) {
          setState(() {
            _aiData = jsonDecode(cachedTips);
            _isLoading = false;
          });
        }
      } else {
        await DataManager().prefetchAllData();
        _loadTipsFromCache();
        return;
      }
    }

    DataManager().markTipsAsViewed();
  }

  // ── Glass Card Helper ──────────────────────────────────────────────
  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    double borderRadius = 24,
    Color? glowColor,
    double blurSigma = 14,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // ── Skeleton Loader ────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Title Header ───────────────────────────────────────────────────
  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Row(
        children: [
          const Text(
            'AI Поради',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryColor,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  'AI',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(),
              Expanded(
                child: _isLoading
                    ? _buildSkeleton()
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _buildHeaderCard(),
                            const SizedBox(height: 28),
                            // Section title
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryColor
                                            .withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Персональні рекомендації",
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Tips list
                            ...(_aiData?['tips'] as List? ?? [])
                                .asMap()
                                .entries
                                .map(
                                  (entry) =>
                                      _buildTipCard(entry.value, entry.key),
                                ),
                            // Footer
                            const SizedBox(height: 32),
                            Center(
                              child: _glassCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                borderRadius: 16,
                                blurSigma: 10,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Нові поради з'являться при наступному вході",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 120),
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

  // ── Header Card ────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    return _glassCard(
      glowColor: AppColors.primaryColor,
      child: Row(
        children: [
          // AI icon with glow
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _aiData?['summary'] ?? "Аналізуємо ваш раціон...",
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tip Card ───────────────────────────────────────────────────────
  Widget _buildTipCard(dynamic tip, int index) {
    // Cycle through accent colors for visual variety
    final accentColors = [
      AppColors.primaryColor,
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFFFF7043),
      const Color(0xFF66BB6A),
    ];
    final accent = accentColors[index % accentColors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _glassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Numbered badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip['title'] ?? "",
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                tip['text'] ?? "",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13.5,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
