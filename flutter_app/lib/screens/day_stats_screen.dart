import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_app/constants/app_colors.dart';

class DayStatsScreen extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic>
  data; // calories, protein, fat, carbs, water + targets

  const DayStatsScreen({super.key, required this.date, required this.data});

  String _monthName(int m) {
    const months = [
      'Січня',
      'Лютого',
      'Березня',
      'Квітня',
      'Травня',
      'Червня',
      'Липня',
      'Серпня',
      'Вересня',
      'Жовтня',
      'Листопада',
      'Грудня',
    ];
    return months[m - 1];
  }

  String _weekdayName(int w) {
    const days = [
      "Понеділок",
      "Вівторок",
      "Середа",
      "Четвер",
      "П'ятниця",
      "Субота",
      "Неділя",
    ];
    return days[w - 1];
  }

  @override
  Widget build(BuildContext context) {
    final int eaten = (data['eaten'] ?? 0).toInt();
    final int target = (data['target'] ?? 2000).toInt();
    final int water = (data['water'] ?? 0).toInt();
    final int wTarget = (data['water_target'] ?? 2000).toInt();
    final int protein = (data['protein'] ?? 0).toInt();
    final int fat = (data['fat'] ?? 0).toInt();
    final int carbs = (data['carbs'] ?? 0).toInt();
    final int tP = (data['target_p'] ?? 150).toInt();
    final int tF = (data['target_f'] ?? 70).toInt();
    final int tC = (data['target_c'] ?? 250).toInt();

    final bool goalMet = eaten >= target && eaten > 0;
    final double calPct = target > 0 ? (eaten / target).clamp(0.0, 1.0) : 0;
    final double wPct = wTarget > 0 ? (water / wTarget).clamp(0.0, 1.0) : 0;

    return AppColors.buildBackgroundWithBlurSpots(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App bar ──────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  children: [
                    Text(
                      '${_weekdayName(date.weekday)}, ${date.day} ${_monthName(date.month)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Статистика дня',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Calorie ring card ─────────────────────────────
                    _CalorieCard(
                      eaten: eaten,
                      target: target,
                      percent: calPct,
                      goalMet: goalMet,
                    ),
                    const SizedBox(height: 16),

                    // ── Macro cards row ───────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _MacroCard(
                            label: 'Білки',
                            icon: Icons.egg_alt_rounded,
                            value: protein,
                            target: tP,
                            color: const Color(0xFF4D9FFF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MacroCard(
                            label: 'Вуглев.',
                            icon: Icons.grain_rounded,
                            value: carbs,
                            target: tC,
                            color: const Color(0xFF9B7FFF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MacroCard(
                            label: 'Жири',
                            icon: Icons.water_drop_rounded,
                            value: fat,
                            target: tF,
                            color: const Color(0xFFFF9F43),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Water card ────────────────────────────────────
                    _WaterCard(water: water, target: wTarget, percent: wPct),
                    const SizedBox(height: 16),

                    // ── Summary pill rows ─────────────────────────────
                    _SummarySection(
                      eaten: eaten,
                      target: target,
                      protein: protein,
                      fat: fat,
                      carbs: carbs,
                      water: water,
                      wTarget: wTarget,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Calorie Ring Card ──────────────────────────────────────────────────────

class _CalorieCard extends StatelessWidget {
  final int eaten, target;
  final double percent;
  final bool goalMet;

  const _CalorieCard({
    required this.eaten,
    required this.target,
    required this.percent,
    required this.goalMet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: goalMet
              ? AppColors.primaryColor.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: goalMet
            ? [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // Ring
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _RingPainter(
                    percent: percent,
                    color: AppColors.primaryColor,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$eaten',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'ккал',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'з $target',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Status pill
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: goalMet
                  ? AppColors.primaryColor.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: goalMet
                    ? AppColors.primaryColor.withValues(alpha: 0.40)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Text(
              goalMet
                  ? '🎯  Ціль виконано!'
                  : 'Залишилось ${(target - eaten).clamp(0, target)} ккал',
              style: TextStyle(
                color: goalMet
                    ? AppColors.primaryColor
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ring Painter ───────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double percent;
  final Color color;

  const _RingPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = -pi / 2;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );

    if (percent <= 0) return;

    // Glow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * pi * percent,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * pi * percent,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + 2 * pi * percent,
          colors: [color, color.withValues(alpha: 0.5)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.percent != percent;
}

// ─── Macro Card ─────────────────────────────────────────────────────────────

class _MacroCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value, target;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (target > 0 ? value / target : 0.0).clamp(0.0, 1.0);
    final done = value >= target && value > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: done ? 0.35 : 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (done)
                Icon(Icons.check_circle_rounded, color: color, size: 13),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$valueг',
            style: TextStyle(
              color: done ? color : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          Text(
            'з $targetг',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Water Card ─────────────────────────────────────────────────────────────

class _WaterCard extends StatelessWidget {
  final int water, target;
  final double percent;

  const _WaterCard({
    required this.water,
    required this.target,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: Colors.blueAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Вода',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$water / $target мл',
                      style: TextStyle(
                        color: Colors.blueAccent.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(percent * 100).toInt()}% добової норми',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Section ─────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  final int eaten, target, protein, fat, carbs, water, wTarget;

  const _SummarySection({
    required this.eaten,
    required this.target,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.water,
    required this.wTarget,
  });

  @override
  Widget build(BuildContext context) {
    final int totalMacroKcal = protein * 4 + carbs * 4 + fat * 9;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Підсумок',
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _row('🔥 Калорії', '$eaten / $target ккал'),
          _row('💧 Вода', '$water / $wTarget мл'),
          _row('🥩 Білки', '$proteinг'),
          _row('🌾 Вуглеводи', '$carbsг'),
          _row('🫙 Жири', '$fatг'),
          if (totalMacroKcal > 0) ...[
            const SizedBox(height: 8),
            Divider(color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 8),
            _row(
              '📊 Ккал з макросів',
              '$totalMacroKcal ккал',
              valueColor: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
