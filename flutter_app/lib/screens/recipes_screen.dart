import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'dart:async';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  Map<String, dynamic>? _recipe;
  bool _isLoading = false; // Це стан генерації (AI думає)
  bool _isEditing = false;
  String _loadingMessage = "AI аналізує ваш раціон...";
  Timer? _timer;

  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  final List<String> _statusMessages = [
    "AI аналізує ваш раціон...",
    "Підраховуємо залишок калорій...",
    "Малюємо апетитне фото страви...",
    "Майже готово, сервіруємо...",
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedRecipe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  // --- КЕШУВАННЯ ---
  Future<void> _loadCachedRecipe() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    final String? cachedString = prefs.getString('cached_recipe_$userId');
    if (cachedString != null) {
      final data = jsonDecode(cachedString);
      if (mounted) {
        setState(() {
          _recipe = data;
          _ingredientsController.text = data['ingredients']?.toString() ?? "";
          _instructionsController.text = data['instructions']?.toString() ?? "";
        });
      }
    }
  }

  void _startLoadingMessages() {
    int index = 0;
    _loadingMessage = _statusMessages[0];
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (index < _statusMessages.length - 1) {
        if (mounted) setState(() => _loadingMessage = _statusMessages[++index]);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _generateRecipe() async {
    setState(() {
      _isLoading = true;
      _recipe = null;
      _isEditing = false;
    });
    _startLoadingMessages();

    try {
      final userId = await AuthService.getStoredUserId();
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/generate_recipe/$userId'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // Зберігаємо в кеш
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_recipe_$userId', res.body);

        if (mounted) {
          setState(() {
            _recipe = data;
            _ingredientsController.text = data['ingredients']?.toString() ?? "";
            _instructionsController.text =
                data['instructions']?.toString() ?? "";
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Помилка генерації. Спробуйте пізніше."),
          ),
        );
      }
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRecipe() async {
    if (_recipe == null) return;
    try {
      final userId = await AuthService.getStoredUserId();

      final Map<String, dynamic> body = {
        "user_id": userId,
        "title": _recipe!['title'] ?? "Без назви",
        "calories": _recipe!['calories'] ?? 0,
        "protein": _recipe!['protein'] ?? 0,
        "fat": _recipe!['fat'] ?? 0,
        "carbs": _recipe!['carbs'] ?? 0,
        "ingredients": _ingredientsController.text,
        "instructions": _instructionsController.text,
        "time": _recipe!['time'] ?? "20 хв",
        "image_url": _recipe!['image_url'],
      };

      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/save_recipe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Збережено з вашими змінами!",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppColors.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          );
          setState(() => _isEditing = false);
        }
      }
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  // --- SKELETON IMAGE LOADER ---
  Widget _buildImageSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                child: Row(
                  children: [
                    const Text(
                      'AI Рецепти',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (_recipe != null && !_isLoading)
                      IconButton(
                        icon: Icon(
                          _isEditing ? Icons.check_circle : Icons.edit_note,
                          color: AppColors.primaryColor,
                          size: 30,
                        ),
                        onPressed: () =>
                            setState(() => _isEditing = !_isEditing),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Персональна страва на основі вашої мети',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 30),

                      // ЛОГІКА ВІДОБРАЖЕННЯ
                      if (_isLoading)
                        _buildLoadingState() // AI генерує
                      else if (_recipe != null)
                        _buildRecipeCard() // Рецепт є (з кешу або новий)
                      else
                        _buildEmptyState(), // Нічого немає

                      const SizedBox(height: 30),

                      if (!_isLoading)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _generateRecipe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _recipe == null
                                  ? "ЗГЕНЕРУВАТИ ВЕЧЕРЮ"
                                  : "ЗГЕНЕРУВАТИ ІНШУ",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
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

  Widget _buildRecipeCard() {
    return _buildStyledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _recipe!['title']?.toString() ?? "Смачна страва",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_recipe!['time'] != null) _buildTimeBadge(_recipe!['time']),
            ],
          ),
          const SizedBox(height: 20),

          if (_recipe!['image_url'] != null && !_isEditing)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                _recipe!['image_url'],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                // Поки картинка вантажиться - показуємо скелетон
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildImageSkeleton();
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: Colors.white10,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.white24),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),
          _buildMacroRow(),
          const SizedBox(height: 25),
          _buildSectionHeader("Інгредієнти", Icons.shopping_basket_outlined),
          const SizedBox(height: 10),
          _isEditing
              ? _buildEditableField(_ingredientsController)
              : Text(
                  _ingredientsController.text,
                  style: const TextStyle(
                    color: Colors.white60,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
          const SizedBox(height: 25),
          _buildSectionHeader("Інструкція", Icons.restaurant_outlined),
          const SizedBox(height: 10),
          _isEditing
              ? _buildEditableField(_instructionsController)
              : Text(
                  _instructionsController.text,
                  style: const TextStyle(
                    color: Colors.white60,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
          const SizedBox(height: 30),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildEditableField(TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: null,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryColor),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.02),
        ),
        onPressed: _saveRecipe,
        icon: Icon(
          _isEditing ? Icons.save_as : Icons.bookmark_border,
          color: AppColors.primaryColor,
        ),
        label: Text(
          _isEditing ? "ЗБЕРЕГТИ ЗМІНИ" : "ЗБЕРЕГТИ У КНИГУ",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBadge(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: AppColors.primaryColor, size: 14),
          const SizedBox(width: 4),
          Text(
            time,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow() {
    return Row(
      children: [
        _macroItem("Ккал", "${_recipe!['calories']}", AppColors.primaryColor),
        _macroItem("Б", "${_recipe!['protein']}г", const Color(0xFF42A5F5)),
        _macroItem("Ж", "${_recipe!['fat']}г", const Color(0xFFFFA726)),
        _macroItem("В", "${_recipe!['carbs']}г", const Color(0xFFAB47BC)),
      ],
    );
  }

  Widget _macroItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassCardColor),
      ),
      child: child,
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(height: 80),
        // Анімований пульсуючий круг
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
                strokeWidth: 10,
              ),
            ),
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
                strokeWidth: 4,
              ),
            ),
            const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          ],
        ),
        const SizedBox(height: 40),
        Text(
          _loadingMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return _buildStyledCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primaryColor, size: 50),
              SizedBox(height: 20),
              Text(
                "Натисніть кнопку нижче,\nщоб AI створив ідеальну страву",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
