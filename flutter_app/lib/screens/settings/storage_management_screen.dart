import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/app_colors.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  bool _isLoading = true;
  double _cacheSizeMB = 0.0;
  double _hiveDataSizeMB = 0.0;
  int _offlineQueueItems = 0;

  @override
  void initState() {
    super.initState();
    _calculateStorageInfo();
  }

  Future<void> _calculateStorageInfo() async {
    setState(() => _isLoading = true);

    try {
      // Кількість елементів в офлайн черзі
      final syncBox = await Hive.openBox('offlineSyncBox');
      _offlineQueueItems = syncBox.length;

      // Розмір кешу програми
      final cacheDir = await getTemporaryDirectory();
      _cacheSizeMB = _calculateDirSize(cacheDir) / (1024 * 1024);

      // Розмір Hive бази даних
      final appDocDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory(appDocDir.path); // Звичайно Hive лежить тут
      _hiveDataSizeMB = _calculateDirSize(hiveDir) / (1024 * 1024);
    } catch (e) {
      debugPrint("Storage calc error: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  int _calculateDirSize(Directory dir) {
    int totalSize = 0;
    try {
      if (dir.existsSync()) {
        dir.listSync(recursive: true, followLinks: false).forEach((entity) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        });
      }
    } catch (e) {
      debugPrint("Error calculating dir size: $e");
    }
    return totalSize;
  }

  Future<void> _clearCache() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        title: Text(
          "Очистити кеш?",
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          "Це звільнить місце, але деякі дані завантажуватимуться довше при наступному відкритті.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Скасувати",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final cacheDir = await getTemporaryDirectory();
              if (cacheDir.existsSync()) {
                cacheDir.deleteSync(recursive: true);
                cacheDir.createSync();
              }
              await _calculateStorageInfo();
            },
            child: Text("Очистити", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearOfflineQueue() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        title: Text(
          "Очистити чергу?",
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          "Ви маєте невідправлені офлайн-дані. Якщо ви очистите чергу, ці зміни не потраплять на сервер. Ви впевнені?",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Скасувати",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final syncBox = await Hive.openBox('offlineSyncBox');
              await syncBox.clear();
              await _calculateStorageInfo();
            },
            child: Text("Видалити зміни", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Сховище',
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // Storage Usage Visualization
                            _buildStorageOverview(),
                            const SizedBox(height: 30),

                            // Details
                            Text(
                              "Деталі",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),

                            _buildDataTile(
                              title: "Кеш додатку",
                              size: _cacheSizeMB,
                              icon: Icons.cached_rounded,
                              actionName: "Очистити",
                              onAction: _clearCache,
                            ),

                            _buildDataTile(
                              title: "Офлайн-черга",
                              subtitle:
                                  "$_offlineQueueItems невідправлених змін",
                              size: 0, // Не має значного розміру
                              icon: Icons.sync_problem_rounded,
                              showSize: false,
                              actionName: "Видалити",
                              onAction: _offlineQueueItems > 0
                                  ? _clearOfflineQueue
                                  : null,
                            ),

                            _buildDataTile(
                              title: "Локальна база (Hive)",
                              subtitle: "Збережений профіль, історія",
                              size: _hiveDataSizeMB,
                              icon: Icons.storage_rounded,
                              showSize: true,
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

  Widget _buildStorageOverview() {
    final totalSizeMB =
        _cacheSizeMB +
        _hiveDataSizeMB +
        (Platform.isIOS
            ? 40.0
            : 65.0); // Додаємо розмір самого додатку приблизно

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.sd_storage_rounded,
            size: 48,
            color: AppColors.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            "${totalSizeMB.toStringAsFixed(1)} МБ",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Загальний простір додатку",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTile({
    required String title,
    String? subtitle,
    required double size,
    required IconData icon,
    bool showSize = true,
    String? actionName,
    VoidCallback? onAction,
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
          onTap: onAction ?? () {},
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primaryColor, size: 24),
                ),
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
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showSize || actionName != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (showSize)
                        Text(
                          "${size < 0.1 ? "<0.1" : size.toStringAsFixed(1)} МБ",
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (actionName != null)
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            actionName,
                            style: TextStyle(
                              color: onAction != null
                                  ? Colors.redAccent
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
