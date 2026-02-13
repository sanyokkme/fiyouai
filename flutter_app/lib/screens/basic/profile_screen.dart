import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';
import '../recipe_book_screen.dart';

import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _appVersion = '';
  String _deviceModel = 'Unknown Device';
  String _lastLogin = '-';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    // 1. App Version
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = "v${packageInfo.version} (${packageInfo.buildNumber})";
      });
    } catch (e) {
      debugPrint("Error loading app version: $e");
    }

    // 2. Device Model
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        setState(
          () => _deviceModel = "${androidInfo.brand} ${androidInfo.model}",
        );
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        setState(() => _deviceModel = _mapIosModel(iosInfo.utsname.machine));
      }
    } catch (e) {
      debugPrint("Error loading device info: $e");
    }

    // 3. Last Login
    final prefs = await SharedPreferences.getInstance();
    final lastLoginStr = prefs.getString('last_login');
    if (lastLoginStr != null) {
      try {
        final date = DateTime.parse(lastLoginStr);
        setState(() {
          _lastLogin = DateFormat('yyyy-MM-dd HH:mm').format(date);
        });
      } catch (e) {
        // ignore
      }
    } else {
      // If missing (migration), set to now
      final now = DateTime.now();
      await prefs.setString('last_login', now.toIso8601String());
      setState(() {
        _lastLogin = DateFormat('yyyy-MM-dd HH:mm').format(now);
      });
    }
  }

  String _mapIosModel(String machine) {
    const modelMap = {
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      'iPhone14,5': 'iPhone 13',
      'iPhone14,2': 'iPhone 13 Pro',
      'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      // Add more as needed or default to machine
    };
    return modelMap[machine] ?? machine;
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
      final token = await AuthService.getAccessToken();
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;

      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/profile/$userId'),
        headers: headers,
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
      baseColor: AppColors.cardColor,
      highlightColor: AppColors.textSecondary.withValues(alpha: 0.1),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 20),
            Container(width: 150, height: 20, color: Colors.black),
            const SizedBox(height: 10),
            Container(width: 200, height: 16, color: Colors.black),
            const SizedBox(height: 35),
            Container(
              height: 150,
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
            icon: Icon(Icons.arrow_back, color: AppColors.textWhite),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Профіль', style: TextStyle(color: AppColors.textWhite)),
        ),
        body: AppColors.buildBackgroundWithBlurSpots(child: _buildSkeleton()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            children: [
              // Header (Back Button + Edit)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppColors.textWhite),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: AppColors.primaryColor),
                      onPressed: () async {
                        if (_userData == null) return;
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(
                              userData: _userData!,
                              onUpdate: (field, val) {},
                            ),
                          ),
                        );
                        if (result == true) _loadProfile();
                      },
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 25),
                      _buildAccountDetailsCard(),
                      const SizedBox(height: 25),
                      const SizedBox(height: 15),
                      _buildSettingsGroups(),
                      const SizedBox(height: 30),
                      Text(
                        "Версія $_appVersion",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
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

  Widget _buildProfileHeader() {
    // Calculate days since registration
    int daysSince = 0;
    if (_userData?['created_at'] != null) {
      try {
        final regDate = DateTime.parse(_userData!['created_at']);
        daysSince = DateTime.now().difference(regDate).inDays;
      } catch (e) {
        /* ignore */
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _uploadAvatar,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryColor, width: 2),
                  image:
                      (_userData?['avatar_url'] != null &&
                          _userData?['avatar_url'] != "")
                      ? DecorationImage(
                          image: NetworkImage(_userData!['avatar_url']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child:
                    (_userData?['avatar_url'] == null ||
                        _userData?['avatar_url'] == "")
                    ? Icon(
                        Icons.person,
                        size: 50,
                        color: AppColors.textSecondary,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryColor),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _userData?['name'] ?? "Користувач",
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _userData?['email'] ?? "email@example.com",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "В додатку вже $daysSince днів",
            style: TextStyle(
              color: AppColors.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Дані",
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, color: AppColors.primaryColor, size: 20),
                onPressed: () {
                  final text =
                      "Підписка: ${_userData?['account_type']}\nПристрій: $_deviceModel\nID користувача: ${_userData?['id']}\nОстанній вхід: $_lastLogin";
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Дані скопійовано"),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: "Скопіювати дані",
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Підписка",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (_userData?['account_type'] == 'pro')
                          ? "PRO"
                          : "Безкоштовна",
                      style: TextStyle(
                        color: _userData?['account_type'] == 'pro'
                            ? AppColors.primaryColor
                            : AppColors.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Пристрій",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _deviceModel,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ID користувача",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _userData?['id'] ?? "-",
                style: TextStyle(color: AppColors.textWhite, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Останній вхід",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _lastLogin,
                style: TextStyle(color: AppColors.textWhite, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroups() {
    return Column(
      children: [
        _buildSettingsGroup("Сповіщення і звуки", [
          _buildSettingsItem(Icons.notifications_outlined, "Сповіщення", () {}),
          _buildSettingsItem(Icons.volume_up_outlined, "Звуки", () {}),
        ]),
        const SizedBox(height: 15),
        _buildSettingsGroup("Приватність і безпека", [
          _buildSettingsItem(Icons.lock_outline, "Змінити пароль", () {}),
          _buildSettingsItem(
            Icons.security,
            "Двофакторна аутентифікація",
            () {},
          ),
        ]),
        const SizedBox(height: 15),
        _buildSettingsGroup("Дані і сховище", [
          _buildSettingsItem(Icons.storage, "Керування сховищем", () {}),
          _buildSettingsItem(Icons.data_usage, "Використання даних", () {}),
        ]),
        const SizedBox(height: 15),
        _buildSettingsGroup("Вигляд", [
          _buildSettingsItem(Icons.palette_outlined, "Тема оформлення", () {}),
          _buildSettingsItem(Icons.wallpaper, "Фон чату", () {}),
        ]),
        const SizedBox(height: 15),
        _buildSettingsGroup("Інше", [
          _buildSettingsItem(Icons.help_outline, "FAQ", () {}),
          _buildSettingsItem(Icons.support_agent, "Допомога", () {}),
          _buildSettingsItem(Icons.info_outline, "Про додаток", () {}),
          _buildSettingsItem(
            Icons.description_outlined,
            "Умови користування",
            () {},
          ),
          _buildSettingsItem(Icons.menu_book_rounded, "Моя Книга Рецептів", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RecipeBookScreen()),
            );
          }),
        ]),
        const SizedBox(height: 15),
        _buildSettingsGroup("Дії з акаунтом", [
          _buildSettingsItem(Icons.logout, "Вийти з акаунту", () async {
            await AuthService.logout();
            if (mounted)
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/welcome', (route) => false);
          }, isDestructive: false),
          _buildSettingsItem(
            Icons.delete_outline,
            "Видалити акаунт",
            _showDeleteConfirmation,
            isDestructive: true,
          ),
        ]),
      ],
    );
  }

  Widget _buildSettingsGroup(String? title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.glassCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.redAccent : AppColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Видалити обліковий запис?',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          'Ця дія незворотна. Всі ваші дані будуть видалені.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Скасувати',
              style: TextStyle(color: AppColors.textWhite),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true); // Show loading
              try {
                final userId = await AuthService.getStoredUserId();
                if (userId != null) {
                  await AuthService.deleteAccount(userId);
                  if (mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/welcome', (route) => false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Акаунт видалено"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Помилка: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Видалити',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
