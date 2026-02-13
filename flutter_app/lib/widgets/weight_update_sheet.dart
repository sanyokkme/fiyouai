import 'package:flutter/material.dart';
import 'package:flutter_app/constants/app_colors.dart';
import 'package:flutter_app/services/auth_service.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_app/services/notification_service.dart';

class WeightUpdateSheet extends StatefulWidget {
  final double currentWeight;
  final Function(double) onWeightUpdated;

  const WeightUpdateSheet({
    super.key,
    required this.currentWeight,
    required this.onWeightUpdated,
  });

  @override
  State<WeightUpdateSheet> createState() => _WeightUpdateSheetState();
}

class _WeightUpdateSheetState extends State<WeightUpdateSheet> {
  late FixedExtentScrollController _kgController;
  late FixedExtentScrollController _gramController;
  final int minKg = 20;
  final int maxKg = 300;

  @override
  void initState() {
    super.initState();
    int initialKg = widget.currentWeight.floor();
    int initialGrams = ((widget.currentWeight - initialKg) * 10).round();

    if (initialKg < minKg) initialKg = minKg;
    if (initialKg > maxKg) initialKg = maxKg;

    _kgController = FixedExtentScrollController(initialItem: initialKg - minKg);
    _gramController = FixedExtentScrollController(initialItem: initialGrams);
  }

  @override
  void dispose() {
    _kgController.dispose();
    _gramController.dispose();
    super.dispose();
  }

  Future<void> _updateWeight(double newWeight) async {
    try {
      final userId = await AuthService.getStoredUserId();
      final token = await AuthService.getAccessToken();
      if (userId == null || token == null) return;

      widget.onWeightUpdated(newWeight);

      // but simple profile update here is fine.

      // Use new weight history endpoint
      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/weight/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"user_id": userId, "weight": newWeight}),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          NotificationService().showInstantNotification(
            "Успіх",
            "Вагу успішно збережено в хмарі ☁️",
          );
        }
      }
    } catch (e) {
      debugPrint("Weight Update Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: AppColors.cardColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Змінити вагу",
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
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  child: ListWheelScrollView.useDelegate(
                    controller: _kgController,
                    itemExtent: 60,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    useMagnifier: true,
                    magnification: 1.2,
                    overAndUnderCenterOpacity: 0.3,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: maxKg - minKg + 1,
                      builder: (context, index) {
                        return Center(
                          child: Text(
                            "${minKg + index}",
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    ".",
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: ListWheelScrollView.useDelegate(
                    controller: _gramController,
                    itemExtent: 60,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    useMagnifier: true,
                    magnification: 1.2,
                    overAndUnderCenterOpacity: 0.3,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 10,
                      builder: (context, index) {
                        return Center(
                          child: Text(
                            "$index",
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    "кг",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  int selectedKg = minKg + _kgController.selectedItem;
                  int selectedGram = _gramController.selectedItem;
                  double finalWeight = selectedKg + (selectedGram / 10.0);
                  _updateWeight(finalWeight).then((_) {
                    Navigator.pop(context, finalWeight);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "ЗБЕРЕГТИ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
