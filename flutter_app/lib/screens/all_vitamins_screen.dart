import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class AllVitaminsScreen extends StatelessWidget {
  final List<dynamic> vitamins;
  final Function(dynamic) onEdit;
  final Function(String) onDelete;

  const AllVitaminsScreen({
    super.key,
    required this.vitamins,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _getVitaminIcon(String type) {
    const Map<String, IconData> types = {
      'pill': Icons.circle,
      'capsule': Icons.change_history,
      'powder': Icons.grain,
      'drops': Icons.water_drop,
      'spray': Icons.air,
      'injection': Icons.vaccines,
    };
    return types[type] ?? Icons.medication;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Мої вітаміни",
          style: GoogleFonts.poppins(
            color: AppColors.textWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: AppColors.buildBackgroundWithBlurSpots(
        child: vitamins.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 80,
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Немає вітамінів",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: vitamins.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final vitamin = vitamins[index];
                  final icon = _getVitaminIcon(vitamin['type'] ?? 'pill');

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onEdit(vitamin);
                    },
                    onLongPress: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.cardColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (ctx) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                ),
                                title: const Text(
                                  "Редагувати",
                                  style: TextStyle(color: Colors.blueAccent),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.pop(context);
                                  onEdit(vitamin);
                                },
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                title: const Text(
                                  "Видалити",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.pop(context);
                                  if (vitamin['id'] != null) {
                                    onDelete(vitamin['id'].toString());
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.textWhite.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: Colors.orangeAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        vitamin['name'] ?? "No Name",
                                        style: TextStyle(
                                          color: AppColors.textWhite,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (vitamin['brand'] != null &&
                                        vitamin['brand']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          "(${vitamin['brand']})",
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (vitamin['description'] != null &&
                                    vitamin['description']
                                        .toString()
                                        .isNotEmpty)
                                  Text(
                                    vitamin['description'].toString(),
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                if (vitamin['schedules'] != null &&
                                    (vitamin['schedules'] as List).isNotEmpty)
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 5,
                                    children: (vitamin['schedules'] as List)
                                        .map(
                                          (schedule) => Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                color: AppColors.textSecondary,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "${schedule['time']} • ${schedule['dose'] ?? 'Не вказано'}",
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
