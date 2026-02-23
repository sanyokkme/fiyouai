import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart'; // Переконайся, що пакет shimmer є в pubspec.yaml
import '../../services/auth_service.dart';
import '../constants/app_colors.dart';

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
        Uri.parse('${AuthService.baseUrl}/search_food?query=$query'),
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

    // Retrieve arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String mealType = args?['mealType'] ?? 'snack';

    int mealIndex = 0;
    switch (mealType) {
      case 'breakfast':
        mealIndex = 0;
        break;
      case 'lunch':
        mealIndex = 1;
        break;
      case 'dinner':
        mealIndex = 2;
        break;
      case 'snack':
      default:
        mealIndex = 3;
        break;
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
      "meal_index": mealIndex,
      "created_at": DateTime.now().toIso8601String(),
    };

    try {
      debugPrint("Sending data: $mealData");

      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/add_manual_meal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(mealData),
      );

      debugPrint("Response status: ${res.statusCode}");
      debugPrint("Response body: ${res.body}");

      if (res.statusCode == 200) {
        return true;
      } else {
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

  Future<bool> _addCustomProductToDatabase({
    required String name,
    required int calories,
    required double protein,
    required double fat,
    required double carbs,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/add_custom_food_product'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'calories': calories,
          'protein': protein,
          'fat': fat,
          'carbs': carbs,
        }),
      );

      if (res.statusCode == 200) {
        return true;
      } else {
        debugPrint('Add custom product failed: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Add custom product error: $e');
      return false;
    }
  }

  void _showAddCustomProductDialog() {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController(text: '0');
    final fatController = TextEditingController(text: '0');
    final carbsController = TextEditingController(text: '0');
    bool isAdding = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          border: Border.all(color: AppColors.textWhite.withValues(alpha: 0.1)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Додати свій продукт',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: nameController,
                      label: 'Назва продукту',
                      hint: 'Наприклад: Банан',
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: caloriesController,
                      label: 'Калорії (на 100г)',
                      hint: '0',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: proteinController,
                            label: 'Білки (г)',
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: fatController,
                            label: 'Жири (г)',
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: carbsController,
                            label: 'Вуглеводи (г)',
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isAdding
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Введіть назву продукту'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                if (caloriesController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Введіть калорії'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isAdding = true);

                                final success =
                                    await _addCustomProductToDatabase(
                                      name: nameController.text.trim(),
                                      calories:
                                          int.tryParse(
                                            caloriesController.text,
                                          ) ??
                                          0,
                                      protein:
                                          double.tryParse(
                                            proteinController.text,
                                          ) ??
                                          0,
                                      fat:
                                          double.tryParse(fatController.text) ??
                                          0,
                                      carbs:
                                          double.tryParse(
                                            carbsController.text,
                                          ) ??
                                          0,
                                    );

                                setModalState(() => isAdding = false);

                                if (success && mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Продукт "${nameController.text.trim()}" додано!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  // Refresh search results
                                  if (_searchController.text.isNotEmpty) {
                                    _performSearch(_searchController.text);
                                  }
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Помилка додавання продукту',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          disabledBackgroundColor: AppColors.primaryColor
                              .withValues(alpha: 0.5),
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
                                'Зберегти продукт',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.textWhite, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textWhite.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textWhite.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _showWeightDialog(Map<String, dynamic> product) {
    final weightController = TextEditingController(text: "100");

    // Змінна для стану завантаження всередині діалогу
    bool isAdding = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          border: Border.all(color: AppColors.textWhite.withValues(alpha: 0.1)),
        ),
        child: StatefulBuilder(
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${product['calories']} ккал / 100г",
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Вкажіть вагу (грами):",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      suffixText: "г",
                      suffixStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: AppColors.textWhite.withValues(alpha: 0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: AppColors.textWhite.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: AppColors.primaryColor,
                          width: 1.5,
                        ),
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
                          child: Text(
                            "Скасувати",
                            style: TextStyle(color: AppColors.textSecondary),
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
                                      int.tryParse(weightController.text) ??
                                      100;

                                  // 2. Виконуємо запит
                                  bool success = await _addFood(
                                    product,
                                    weight,
                                  );

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
                            backgroundColor: AppColors.primaryColor,
                            disabledBackgroundColor: AppColors.primaryColor
                                .withValues(alpha: 0.5),
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
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: AppColors.cardColor,
          highlightColor: AppColors.textGrey.withValues(alpha: 0.3),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.cardColor,
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
          Icon(
            Icons.search,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 15),
          Text(
            "Введіть назву продукту",
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
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
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          // Локальні продукти підсвічуємо ледь помітним зеленим, глобальні - прозорим
          color: isGlobal
              ? Colors.transparent
              : AppColors.primaryColor.withValues(alpha: 0.2),
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
                        ? Colors.blueAccent.withValues(
                            alpha: 0.1,
                          ) // Синій для інтернету
                        : AppColors.primaryColor.withValues(
                            alpha: 0.1,
                          ), // Зелений для своїх
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    // Різні іконки
                    isGlobal ? Icons.public : Icons.storage,
                    color: isGlobal
                        ? Colors.blueAccent
                        : AppColors.primaryColor,
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
                        style: TextStyle(
                          color: AppColors.textWhite,
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
                                color: Colors.blueAccent.withValues(alpha: 0.2),
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
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Б:${item['protein']} Ж:${item['fat']} В:${item['carbs']}",
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
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
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: AppColors.primaryColor),
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
      backgroundColor: AppColors.backgroundDark,
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
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
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

            // "Не знайшли продукту?" link - показується коли результатів не знайдено
            if (_searchResults.isEmpty ||
                _searchResults.isNotEmpty &&
                    !_isLoading &&
                    _searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _showAddCustomProductDialog,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: AppColors.primaryColor,
                      size: 18,
                    ),
                    label: Text(
                      'Не знайшли продукту?',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
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
