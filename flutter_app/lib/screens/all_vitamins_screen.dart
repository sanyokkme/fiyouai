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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Мої вітаміни",
          style: GoogleFonts.poppins(
            color: Colors.white,
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
                  children: const [
                    Icon(
                      Icons.medication_outlined,
                      size: 80,
                      color: Colors.white24,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Немає вітамінів",
                      style: TextStyle(color: Colors.white54, fontSize: 18),
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
                        backgroundColor: const Color(0xFF1A1A1A),
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
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
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
                                        style: const TextStyle(
                                          color: Colors.white,
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
                                          style: const TextStyle(
                                            color: Colors.white54,
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
                                    style: const TextStyle(
                                      color: Colors.white70,
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
                                              const Icon(
                                                Icons.access_time,
                                                color: Colors.white38,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "${schedule['time']} • ${schedule['dose'] ?? 'Не вказано'}",
                                                style: const TextStyle(
                                                  color: Colors.white38,
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
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white24,
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
