import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../services/auth_service.dart';

class RecipeBookScreen extends StatefulWidget {
  const RecipeBookScreen({super.key});

  @override
  State<RecipeBookScreen> createState() => _RecipeBookScreenState();
}

class _RecipeBookScreenState extends State<RecipeBookScreen> {
  List<dynamic> _savedRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedRecipes();
  }

  Future<void> _loadSavedRecipes() async {
    try {
      final userId = await AuthService.getStoredUserId();
      final res = await http.get(
        Uri.parse('http://${AuthService.serverIp}:8000/saved_recipes/$userId'),
      );
      if (res.statusCode == 200) {
        setState(() {
          _savedRecipes = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRecipe(String recipeId, int index) async {
    try {
      final res = await http.delete(
        Uri.parse(
          'http://${AuthService.serverIp}:8000/delete_recipe/$recipeId',
        ),
      );
      if (res.statusCode == 200) {
        setState(() {
          _savedRecipes.removeAt(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Рецепт видалено"),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  String _formatData(dynamic data) {
    if (data is List) return data.join("\n• ");
    return data?.toString() ?? "";
  }

  void _shareRecipe(dynamic recipe) {
    final String ingredients = _formatData(recipe['ingredients']);
    final String instructions = _formatData(recipe['instructions']);
    final String text =
        "🍴 ${recipe['recipe_name'] ?? recipe['title'] ?? 'Смачна страва'}\n\n"
        "🔥 Калорійність: ${recipe['calories']} ккал\n"
        "🕒 Час: ${recipe['time'] ?? 'не вказано'}\n\n"
        "📦 Інгредієнти:\n$ingredients\n\n"
        "👨‍🍳 Спосіб приготування:\n$instructions\n\n"
        "Згенеровано в NutritionAI 2026";
    Share.share(text, subject: 'Мій AI рецепт!');
  }

  Future<void> _markAsEaten(dynamic recipe) async {
    try {
      final userId = await AuthService.getStoredUserId();
      final res = await http.post(
        Uri.parse('http://${AuthService.serverIp}:8000/add_from_recipe'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "recipe": {
            "title": recipe['recipe_name'] ?? recipe['title'],
            "calories": recipe['calories'] ?? 0,
            "protein": recipe['protein'] ?? recipe['proteins'] ?? 0,
            "fat": recipe['fat'] ?? recipe['fats'] ?? 0,
            "carbs": recipe['carbs'] ?? recipe['carbohydrates'] ?? 0,
          },
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Смачного! Дані оновлено 🥗",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.greenAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Мої рецепти',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      )
                    : _savedRecipes.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: _savedRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = _savedRecipes[index];
                          return Dismissible(
                            key: Key(recipe['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 25),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                Icons.delete_sweep,
                                color: Colors.redAccent,
                                size: 30,
                              ),
                            ),
                            onDismissed: (_) =>
                                _deleteRecipe(recipe['id'].toString(), index),
                            child: _buildRecipeCard(recipe),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeCard(dynamic recipe) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: recipe['image_url'] != null
              ? Image.network(
                  recipe['image_url'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _defaultIcon(),
                )
              : _defaultIcon(),
        ),
        title: Text(
          recipe['recipe_name'] ?? recipe['title'] ?? "Без назви",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            "${recipe['calories']} ккал • ${recipe['time'] ?? '20 хв'}",
            style: const TextStyle(color: Colors.white38),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.white24,
        ),
        onTap: () => _showDetails(recipe),
      ),
    );
  }

  Widget _defaultIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.restaurant_menu,
        color: Colors.greenAccent,
        size: 20,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 80,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 20),
          const Text(
            "Ваша книга порожня",
            style: TextStyle(color: Colors.white38, fontSize: 18),
          ),
        ],
      ),
    );
  }

  void _showDetails(dynamic recipe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (recipe['image_url'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        recipe['image_url'],
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          recipe['recipe_name'] ?? recipe['title'] ?? "Рецепт",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.share_outlined,
                          color: Colors.greenAccent,
                        ),
                        onPressed: () => _shareRecipe(recipe),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildMacroRow(recipe),
                  const Divider(color: Colors.white10, height: 40),
                  const Text(
                    "📦 Інгредієнти",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _formatData(recipe['ingredients']),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "👨‍🍳 Спосіб приготування",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _formatData(recipe['instructions']),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 30,
              left: 30,
              right: 30,
              child: ElevatedButton(
                onPressed: () => _markAsEaten(recipe),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 10,
                ),
                child: const Text(
                  "ПРИГОТОВАНО",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow(dynamic recipe) {
    return Row(
      children: [
        _macroChip("${recipe['calories']} ккал", Colors.greenAccent),
        const SizedBox(width: 8),
        _macroChip("${recipe['protein']}г Б", Colors.blueAccent),
        const SizedBox(width: 8),
        _macroChip("${recipe['fat']}г Ж", Colors.orangeAccent),
        const SizedBox(width: 8),
        _macroChip("${recipe['carbs']}г В", Colors.purpleAccent),
      ],
    );
  }

  Widget _macroChip(String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
