import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';
import '../recipe_book_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _picker = ImagePicker();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

    // 1. КЕШ (Миттєво)
    final cachedProfile = prefs.getString('cached_profile_$userId');
    if (cachedProfile != null) {
      if (mounted) {
        setState(() {
          _userData = jsonDecode(cachedProfile);
          _isLoading = false;
        });
      }
    }

    try {
      // 2. МЕРЕЖА (У фоні)
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/profile/$userId'),
      );

      if (response.statusCode == 200) {
        // Зберігаємо свіжі дані
        await prefs.setString('cached_profile_$userId', response.body);

        if (mounted) {
          setState(() {
            _userData = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      // Якщо кешу немає і помилка мережі - припиняємо завантаження
      if (mounted && _userData == null) setState(() => _isLoading = false);
    }
  }

  // --- ЛОГІКА ПЕРЕКЛАДУ ---
  String _getGoalTranslation(String? goal) {
    switch (goal?.toLowerCase()) {
      case 'gain':
      case 'gain_muscle':
        return "Набір маси";
      case 'lose':
      case 'lose_weight':
        return "Схуднення";
      default:
        return "Підтримка ваги";
    }
  }

  IconData _getGoalIcon(String? goal) {
    if (goal?.contains('gain') == true) return Icons.fitness_center;
    if (goal?.contains('lose') == true) return Icons.trending_down;
    return Icons.auto_awesome;
  }

  // --- API UPDATE ---
  Future<void> _updateField(String field, dynamic newValue) async {
    // Оптимістичне оновлення UI
    setState(() {
      _userData?[field] = newValue;
    });

    try {
      final userId = await AuthService.getStoredUserId();
      await http.post(
        Uri.parse('${AuthService.baseUrl}/profile/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": userId,
          "field": field,
          "value": newValue.toString(),
        }),
      );
      // Оновлюємо кеш новими даними
      final prefs = await SharedPreferences.getInstance();
      if (_userData != null) {
        prefs.setString('cached_profile_$userId', jsonEncode(_userData));
      }
    } catch (e) {
      debugPrint("Update error: $e");
      // Тут можна додати логіку відкату змін (rollback), якщо потрібно
    }
  }

  Future<void> _uploadAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Показуємо локальний індикатор, що почалось завантаження
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Завантаження фото..."),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final userId = await AuthService.getStoredUserId();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AuthService.baseUrl}/profile/avatar'),
      );
      request.fields['user_id'] = userId ?? "";
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        _loadProfile(); // Перезавантажуємо профіль, щоб отримати новий URL
      }
    } catch (e) {
      debugPrint("Avatar error: $e");
    }
  }

  // --- SKELETON LOADER ---
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(radius: 60, backgroundColor: Colors.black),
            const SizedBox(height: 15),
            Container(width: 200, height: 20, color: Colors.black),
            const SizedBox(height: 35),
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _userData == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Профіль', style: TextStyle(color: Colors.white)),
        ),
        body: AppColors.buildBackgroundWithBlurSpots(child: _buildSkeleton()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
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
                      'Профіль',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildAvatarSection(),
                      const SizedBox(height: 15),
                      Text(
                        _userData?['email'] ?? "Пошта не вказана",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      _buildGoalBadge(_userData?['goal']),
                      const SizedBox(height: 35),

                      // Характеристики з "Барабанами"
                      _buildInfoCard(
                        "Стать",
                        "",
                        Icons.wc,
                        false,
                        'gender',
                        customTrailing: _buildGenderDisplay(
                          _userData?['gender'],
                        ),
                      ),

                      _buildInfoCard(
                        "Вік",
                        "${_userData?['age'] ?? 0} років",
                        Icons.cake_outlined,
                        true,
                        'age',
                        onEdit: () => _showWheelPicker(
                          "Вік",
                          10,
                          100,
                          _userData?['age'],
                          "",
                          (val) => _updateField('age', val),
                        ),
                      ),

                      _buildInfoCard(
                        "Ріст",
                        "${_userData?['height'] ?? 0} см",
                        Icons.height,
                        true,
                        'height',
                        onEdit: () => _showWheelPicker(
                          "Ріст",
                          100,
                          230,
                          _userData?['height'],
                          "см",
                          (val) => _updateField('height', val),
                        ),
                      ),

                      _buildInfoCard(
                        "Вага",
                        "${_userData?['weight'] ?? 0} кг",
                        Icons.monitor_weight_outlined,
                        true,
                        'weight',
                        onEdit: () => _showWheelPicker(
                          "Вага",
                          30,
                          200,
                          _userData?['weight'],
                          "кг",
                          (val) => _updateField('weight', val),
                        ),
                      ),

                      const SizedBox(height: 25),
                      _buildActionButton(
                        "Моя Книга Рецептів",
                        Icons.menu_book_rounded,
                        () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const RecipeBookScreen(),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                            transitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                          ),
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 60),
                      _buildLogoutButton(),
                      const SizedBox(height: 40),
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

  // --- WIDGETS ---

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white10,
            backgroundImage:
                (_userData?['avatar_url'] != null &&
                    _userData?['avatar_url'] != "")
                ? NetworkImage(_userData!['avatar_url'])
                : null,
            child:
                (_userData?['avatar_url'] == null ||
                    _userData?['avatar_url'] == "")
                ? const Icon(
                    Icons.person,
                    size: 60,
                    color: AppColors.primaryColor,
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _uploadAvatar,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalBadge(String? goal) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundDarkAccent,
            AppColors.primaryColor.withValues(alpha: 0.5),
            AppColors.backgroundDarkAccent,
          ],
          stops: [0.7, 0.3, 0.7],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getGoalIcon(goal), color: AppColors.primaryColor, size: 18),
          const SizedBox(width: 10),
          Text(
            _getGoalTranslation(goal).toUpperCase(),
            style: const TextStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    bool editable,
    String fieldKey, {
    Widget? customTrailing,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 22),
          const SizedBox(width: 15),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const Spacer(),
          if (customTrailing != null)
            customTrailing
          else
            GestureDetector(
              onTap: editable ? onEdit : null,
              child: Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (editable) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.edit, color: Colors.white24, size: 16),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGenderDisplay(String? gender) {
    final g = (gender ?? "").toLowerCase();
    IconData icon = (g.contains('чоловік') || g == 'male')
        ? Icons.male
        : (g.contains('жінка') || g == 'female')
        ? Icons.female
        : Icons.transgender;
    Color color = (g.contains('чоловік') || g == 'male')
        ? Colors.blueAccent
        : Colors.pinkAccent;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.02),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryColor),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // --- STYLISH WHEEL PICKER (БАРАБАН) ---
  void _showWheelPicker(
    String title,
    int min,
    int max,
    dynamic currentVal,
    String unit,
    Function(int) onSave,
  ) {
    int initialValue = int.tryParse(currentVal.toString()) ?? min;
    // Фікс для безпеки, якщо значення з бази виходить за межі
    if (initialValue < min) initialValue = min;
    if (initialValue > max) initialValue = max;

    int selectedValue = initialValue;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 350,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Змінити $title",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
            ),

            // Wheel
            Expanded(
              child: ListWheelScrollView.useDelegate(
                itemExtent: 60,
                perspective: 0.005,
                diameterRatio: 1.2,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) {
                  selectedValue = min + index;
                },
                controller: FixedExtentScrollController(
                  initialItem: initialValue - min,
                ),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: max - min + 1,
                  builder: (context, index) {
                    final value = min + index;
                    return Center(
                      child: Text(
                        "$value $unit",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(25),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    onSave(selectedValue);
                    Navigator.pop(context);
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
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.redAccent),
          ),
        ),
        onPressed: () async {
          await _authService.logout();
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        },
        child: const Text(
          "ВИЙТИ З АККАУНТУ",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
