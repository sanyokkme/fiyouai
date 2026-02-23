import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function(String, dynamic) onUpdate;

  const EditProfileScreen({
    super.key,
    required this.userData,
    required this.onUpdate,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  String _selectedGender = 'male';
  String _selectedActivity = 'Sedentary';
  String _selectedGoal = 'Maintain';
  DateTime? _selectedDob;
  bool _isLoading = false;

  final List<String> _genders = ['Чоловік', 'Жінка'];
  final List<String> _activityLevels = [
    "Сидячий",
    "Легка активність",
    "Середня активність",
    "Висока активність",
  ];
  final List<String> _goals = ['Схуднення', 'Підтримка ваги', 'Набір маси'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    _heightController = TextEditingController(
      text: widget.userData['height']?.toString(),
    );
    _weightController = TextEditingController(
      text: widget.userData['weight']?.toString(),
    );

    _selectedGender = widget.userData['gender'] ?? 'Чоловік';
    _selectedActivity = widget.userData['activity_level'] ?? 'Сидячий';
    _selectedGoal = widget.userData['goal'] ?? 'Підтримка ваги';

    if (!_genders.contains(_selectedGender)) _selectedGender = _genders[0];
    if (!_activityLevels.contains(_selectedActivity)) {
      _selectedActivity = _activityLevels[0];
    }

    if (widget.userData['dob'] != null) {
      try {
        _selectedDob = DateTime.parse(widget.userData['dob']);
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'name': _nameController.text,
        'gender': _selectedGender,
        'activity_level': _selectedActivity,
        'goal': _selectedGoal,
        'height': _heightController.text,
        'weight': _weightController.text,
        'dob': _selectedDob?.toIso8601String().split('T')[0],
      };

      for (var entry in updates.entries) {
        if (entry.value != widget.userData[entry.key]?.toString()) {
          await AuthService.updateProfile(entry.key, entry.value);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Помилка збереження: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Glass Card Helper ──────────────────────────────────────────────
  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    double borderRadius = 24,
    Color? glowColor,
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
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      "Редагувати",
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    // Save button
                    GestureDetector(
                      onTap: _isLoading ? null : _save,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: _isLoading
                                ? Padding(
                                    padding: const EdgeInsets.all(11),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryColor,
                                    ),
                                  )
                                : Icon(
                                    Icons.check_rounded,
                                    color: AppColors.primaryColor,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form ───────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _glassCard(
                          glowColor: AppColors.primaryColor,
                          child: Column(
                            children: [
                              _buildTextField("Ім'я", _nameController),
                              const SizedBox(height: 20),
                              _buildDropdown(
                                "Стать",
                                _selectedGender,
                                _genders,
                                (val) => setState(() => _selectedGender = val!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _glassCard(
                          child: Column(
                            children: [
                              _buildDropdown(
                                "Рівень активності",
                                _selectedActivity,
                                _activityLevels,
                                (val) =>
                                    setState(() => _selectedActivity = val!),
                              ),
                              const SizedBox(height: 20),
                              _buildDropdown(
                                "Ваша ціль",
                                _selectedGoal,
                                _goals,
                                (val) => setState(() => _selectedGoal = val!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _glassCard(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      "Ріст (см)",
                                      _heightController,
                                      isNumber: true,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      "Вага (кг)",
                                      _weightController,
                                      isNumber: true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildDatePicker(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Text Field ─────────────────────────────────────────────────────
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: AppColors.primaryColor,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.primaryColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (val) =>
              val == null || val.isEmpty ? "Обов'язкове поле" : null,
        ),
      ],
    );
  }

  // ── Dropdown ───────────────────────────────────────────────────────
  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A2E),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              borderRadius: BorderRadius.circular(16),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ── Date Picker ────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Дата народження",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDob ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: AppColors.primaryColor,
                      onPrimary: Colors.black,
                      surface: const Color(0xFF1A1A2E),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) setState(() => _selectedDob = picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDob == null
                        ? "Оберіть дату"
                        : "${_selectedDob!.day.toString().padLeft(2, '0')}.${_selectedDob!.month.toString().padLeft(2, '0')}.${_selectedDob!.year}",
                    style: TextStyle(
                      color: _selectedDob == null
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
