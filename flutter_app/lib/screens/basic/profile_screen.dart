import 'dart:ui';
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

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _appVersion = '';
  String _deviceModel = 'Unknown Device';
  String _lastLogin = '-';
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDeviceInfo();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = "v${packageInfo.version} (${packageInfo.buildNumber})";
      });
    } catch (e) {
      debugPrint("Error loading app version: $e");
    }

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
    };
    return modelMap[machine] ?? machine;
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AuthService.getStoredUserId();
    if (userId == null) return;

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
      final response = await AuthService.authGet('/profile/$userId');
      if (response.statusCode == 200) {
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
      if (mounted && _userData == null) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

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
        _loadProfile();
      }
    } catch (e) {
      debugPrint("Avatar error: $e");
    }
  }

  // ── Glass Card Helper ──────────────────────────────────────────────
  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    double borderRadius = 24,
    Color? glowColor,
    double blurSigma = 14,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.12),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 200,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading && _userData == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
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
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 28),
                      _buildAccountDetailsCard(),
                      const SizedBox(height: 28),
                      _buildSettingsGroups(),
                      const SizedBox(height: 32),
                      Text(
                        "FiYou AI  •  $_appVersion",
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                          fontSize: 11,
                          letterSpacing: 0.5,
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

  // ── Top Bar ────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 42),
          Text(
            "Профіль",
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          _iconBtn(
            icon: Icons.edit_outlined,
            color: AppColors.primaryColor,
            onTap: () async {
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
    );
  }

  Widget _iconBtn({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color ?? Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile Header ─────────────────────────────────────────────────
  Widget _buildProfileHeader() {
    int daysSince = 0;
    if (_userData?['created_at'] != null) {
      try {
        final regDate = DateTime.parse(_userData!['created_at']);
        daysSince = DateTime.now().difference(regDate).inDays;
      } catch (_) {}
    }

    final isPro = _userData?['account_type'] == 'pro';
    final hasAvatar =
        _userData?['avatar_url'] != null &&
        _userData!['avatar_url'].toString().isNotEmpty;

    return Column(
      children: [
        // Avatar with animated glow ring
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return GestureDetector(
              onTap: _uploadAvatar,
              child: Stack(
                children: [
                  // Outer glow
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(
                            alpha: 0.3 * _glowAnimation.value,
                          ),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  // Avatar border
                  Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryColor,
                          AppColors.primaryColor.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.backgroundDark,
                        image: hasAvatar
                            ? DecorationImage(
                                image: NetworkImage(_userData!['avatar_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: !hasAvatar
                          ? Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                  ),
                  // Camera badge
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.5,
                            ),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          _userData?['name'] ?? "Користувач",
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),

        // Email
        Text(
          _userData?['email'] ?? "email@example.com",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 14),

        // Badges row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _infoBadge(icon: Icons.bolt_rounded, label: "$daysSince днів"),
            const SizedBox(width: 10),
            _infoBadge(
              icon: isPro
                  ? Icons.workspace_premium_rounded
                  : Icons.person_outline,
              label: isPro ? "PRO" : "Безкоштовна",
              glow: isPro,
              color: isPro ? AppColors.primaryColor : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoBadge({
    required IconData icon,
    required String label,
    bool glow = false,
    Color? color,
  }) {
    final badgeColor = color ?? Colors.white.withValues(alpha: 0.5);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: badgeColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Account Details Card ───────────────────────────────────────────
  Widget _buildAccountDetailsCard() {
    return _glassCard(
      glowColor: AppColors.primaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Дані акаунту",
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  final text =
                      "Підписка: ${_userData?['account_type']}\nПристрій: $_deviceModel\nID: ${_userData?['id']}\nОстанній вхід: $_lastLogin";
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Дані скопійовано"),
                      duration: const Duration(seconds: 1),
                      backgroundColor: AppColors.primaryColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    color: AppColors.primaryColor,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _divider(),
          const SizedBox(height: 16),

          // Data grid
          Row(
            children: [
              Expanded(
                child: _dataCell(
                  icon: Icons.devices_rounded,
                  label: "Пристрій",
                  value: _deviceModel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dataCell(
                  icon: Icons.schedule_rounded,
                  label: "Останній вхід",
                  value: _lastLogin,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 16),

          // User ID
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.tag_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  _userData?['id'] ?? "-",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataCell({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 13,
                color: AppColors.primaryColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── Settings ───────────────────────────────────────────────────────
  Widget _buildSettingsGroups() {
    return Column(
      children: [
        _buildSettingsGroup(
          "Сповіщення і звуки",
          Icons.notifications_outlined,
          [
            _settingsItem(
              Icons.notifications_outlined,
              "Сповіщення",
              onTap: () {},
            ),
            _settingsItem(Icons.volume_up_outlined, "Звуки", onTap: () {}),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsGroup("Приватність і безпека", Icons.lock_outline, [
          _settingsItem(Icons.lock_outline, "Змінити пароль", onTap: () {}),
          _settingsItem(
            Icons.security_rounded,
            "Двофакторна аутентифікація",
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup("Дані і сховище", Icons.storage_rounded, [
          _settingsItem(
            Icons.storage_rounded,
            "Керування сховищем",
            onTap: () {},
          ),
          _settingsItem(
            Icons.data_usage_rounded,
            "Використання даних",
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup("Вигляд", Icons.palette_outlined, [
          _settingsItem(
            Icons.palette_outlined,
            "Тема оформлення",
            onTap: () {},
          ),
          _settingsItem(Icons.wallpaper_rounded, "Фон чату", onTap: () {}),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup("Інше", Icons.info_outline, [
          _settingsItem(Icons.help_outline, "FAQ", onTap: () {}),
          _settingsItem(Icons.support_agent_rounded, "Допомога", onTap: () {}),
          _settingsItem(Icons.info_outline, "Про додаток", onTap: () {}),
          _settingsItem(
            Icons.description_outlined,
            "Умови користування",
            onTap: () {},
          ),
          _settingsItem(
            Icons.menu_book_rounded,
            "Моя Книга Рецептів",
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                "NEW",
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecipeBookScreen(),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup("Дії з акаунтом", Icons.manage_accounts_rounded, [
          _settingsItem(
            Icons.logout_rounded,
            "Вийти з акаунту",
            onTap: () async {
              await AuthService.logout();
              if (mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/welcome', (route) => false);
              }
            },
          ),
          _settingsItem(
            Icons.delete_outline_rounded,
            "Видалити акаунт",
            isDestructive: true,
            onTap: _showDeleteConfirmation,
          ),
        ]),
      ],
    );
  }

  Widget _buildSettingsGroup(
    String title,
    IconData titleIcon,
    List<Widget> children,
  ) {
    return _glassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Icon(
                  titleIcon,
                  size: 14,
                  color: AppColors.primaryColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          _divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _settingsItem(
    IconData icon,
    String title, {
    required VoidCallback onTap,
    bool isDestructive = false,
    Widget? trailing,
  }) {
    final color = isDestructive
        ? Colors.redAccent
        : Colors.white.withValues(alpha: 0.5);
    final textColor = isDestructive ? Colors.redAccent : AppColors.textWhite;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(0),
        splashColor: AppColors.primaryColor.withValues(alpha: 0.06),
        highlightColor: AppColors.primaryColor.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDestructive ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: color.withValues(alpha: isDestructive ? 0.2 : 0.1),
                  ),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[trailing, const SizedBox(width: 8)],
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  Widget _divider() {
    return Divider(
      height: 0,
      thickness: 0.5,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  // ── Delete Dialog ──────────────────────────────────────────────────
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Видалити акаунт?',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Ця дія незворотна.\nВсі ваші дані будуть видалені назавжди.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.textWhite),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Видалити',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
