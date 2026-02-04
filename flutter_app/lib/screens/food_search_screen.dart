import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart'; // Переконайся, що пакет shimmer є в pubspec.yaml
import '../../services/auth_service.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Автоматично ставимо фокус на поле вводу при відкритті
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final res = await http.get(
        Uri.parse(
          'http://${AuthService.serverIp}:8000/search_food?query=$query',
        ),
      );

      if (res.statusCode == 200) {
        // --- ВИПРАВЛЕННЯ ТУТ ---
        final data = jsonDecode(res.body);

        if (data is List) {
          setState(() {
            _searchResults = data;
          });
        } else {
          // Якщо сервер повернув не список, а помилку (Map)
          debugPrint("Server returned error object: $data");
          setState(() {
            _searchResults = [];
          });
        }
      } else {
        debugPrint("Search failed: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Search Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _addFood(Map<String, dynamic> product, int weight) async {
    final userId = await AuthService.getStoredUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Помилка: Не знайдено ID користувача")),
      );
      return false;
    }

    double multiplier = weight / 100.0;

    final mealData = {
      "user_id": userId,
      "meal_name": product['name'],
      "calories": (product['calories'] * multiplier).round(),
      "protein": double.parse(
        (product['protein'] * multiplier).toStringAsFixed(1),
      ),
      "fat": double.parse((product['fat'] * multiplier).toStringAsFixed(1)),
      "carbs": double.parse((product['carbs'] * multiplier).toStringAsFixed(1)),
      "created_at": DateTime.now().toIso8601String(),
    };

    try {
      debugPrint("Sending data: $mealData"); // ДЛЯ ВІДЛАДКИ

      final res = await http.post(
        Uri.parse('http://${AuthService.serverIp}:8000/add_manual_meal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(mealData),
      );

      debugPrint("Response status: ${res.statusCode}");
      debugPrint("Response body: ${res.body}");

      if (res.statusCode == 200) {
        return true; // Успіх
      } else {
        // Показуємо помилку з сервера
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Помилка сервера: ${res.statusCode}\n${res.body}"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint("Add Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Помилка з'єднання: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  void _showWeightDialog(Map<String, dynamic> product) {
    final weightController = TextEditingController(text: "100");

    // Змінна для стану завантаження всередині діалогу
    bool isAdding = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => StatefulBuilder(
        // Додаємо це, щоб оновлювати кнопку
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${product['calories']} ккал / 100г",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Вкажіть вагу (грами):",
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    suffixText: "г",
                    suffixStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.greenAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isAdding ? null : () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          "Скасувати",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isAdding
                            ? null
                            : () async {
                                // 1. Блокуємо кнопку
                                setModalState(() => isAdding = true);

                                int weight =
                                    int.tryParse(weightController.text) ?? 100;

                                // 2. Виконуємо запит
                                bool success = await _addFood(product, weight);

                                // 3. Розблоковуємо
                                setModalState(() => isAdding = false);

                                // 4. Якщо успіх - закриваємо і показуємо SnackBar
                                if (success && mounted) {
                                  Navigator.pop(ctx);
                                  // Повертаємось з результатом true, щоб оновити Home
                                  Navigator.pop(context, true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Успішно додано: ${product['name']}",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          disabledBackgroundColor: Colors.greenAccent
                              .withOpacity(0.5),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: isAdding
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Додати",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 15),
          Text(
            "Введіть назву продукту",
            style: TextStyle(color: Colors.white.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    // Визначаємо джерело: local (твоя база) чи global (інтернет)
    bool isGlobal = item['source'] == 'global';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          // Локальні продукти підсвічуємо ледь помітним зеленим, глобальні - прозорим
          color: isGlobal
              ? Colors.transparent
              : Colors.greenAccent.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showWeightDialog(item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                // --- ІКОНКА ТИПУ ПРОДУКТУ ---
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isGlobal
                        ? Colors.blueAccent.withOpacity(
                            0.1,
                          ) // Синій для інтернету
                        : Colors.greenAccent.withOpacity(
                            0.1,
                          ), // Зелений для своїх
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    // Різні іконки
                    isGlobal ? Icons.public : Icons.storage,
                    color: isGlobal ? Colors.blueAccent : Colors.greenAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 15),

                // --- ІНФОРМАЦІЯ ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Якщо це глобальний пошук, додаємо маленький бейдж
                          if (isGlobal)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "WEB",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 8,
                                ),
                              ),
                            ),

                          Text(
                            "${item['calories']} ккал",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Б:${item['protein']} Ж:${item['fat']} В:${item['carbs']}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Кнопка "+"
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.greenAccent),
                    onPressed: () => _showWeightDialog(item),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // Пошуковий рядок
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.white38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Пошук (напр. 'Банан')",
                                hintStyle: TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              child: const Icon(
                                Icons.close,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Список результатів
            Expanded(
              child: _isLoading
                  ? _buildShimmerLoading() // Красиве завантаження
                  : _searchResults.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        return _buildProductItem(_searchResults[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
