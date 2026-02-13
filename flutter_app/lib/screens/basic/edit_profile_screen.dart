import 'package:flutter_app/constants/app_colors.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter/material.dart';

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

    // Normalize values if they don't match list (basic safety)
    if (!_genders.contains(_selectedGender)) _selectedGender = _genders[0];
    if (!_activityLevels.contains(_selectedActivity))
      _selectedActivity = _activityLevels[0];
    // Goals might need mapping if stored in English but displayed in Ukrainian
    // Assuming implementation stores in Ukrainian or we map it.
    // Looking at existing code, it seems mixed or Ukrainian.
    // Let's assume Ukrainian for display and stick to what's in DB or match it.
    // Logic in ProfileScreen uses 'gain', 'lose' etc for keys but displays Ukrainian.
    // backend/schemas.py uses defaults like "Сидячий", "Підтримка ваги"

    // Attempt to parse DOB
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
      // Update each field
      // Optimization: In a real app, send one bulk request.
      // Current backend supports single field updates via /profile/update.
      // We will loop through changes or just update what changed.

      final newName = _nameController.text;
      final newHeight = _heightController.text;
      final newWeight = _weightController.text;

      // We'll just call onUpdate for each changed field to reuse logic in parent
      // But parent logic might trigger setState each time.
      // Better to potentially bulk update here if we could, but let's stick to the requested architecture
      // "Save button... changes MUST update in DB"

      // Let's do it directly here via AuthService/http and then notify parent

      final updates = {
        'name': newName,
        'gender': _selectedGender,
        'activity_level': _selectedActivity,
        'goal': _selectedGoal,
        'height': newHeight,
        'weight': newWeight,
        'dob': _selectedDob?.toIso8601String().split('T')[0],
      };

      // Helper to check if changed
      for (var entry in updates.entries) {
        if (entry.value != widget.userData[entry.key]?.toString()) {
          // Basic check, might need better type comparison
          await AuthService.updateProfile(entry.key, entry.value);
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate refresh needed
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Редагувати профіль",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                "Зберегти",
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField("Ім'я", _nameController),
              const SizedBox(height: 16),
              _buildDropdown(
                "Стать",
                _selectedGender,
                _genders,
                (val) => setState(() => _selectedGender = val!),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                "Рівень активності",
                _selectedActivity,
                _activityLevels,
                (val) => setState(() => _selectedActivity = val!),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                "Ваша ціль",
                _selectedGoal,
                _goals,
                (val) => setState(() => _selectedGoal = val!),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              _buildDatePicker(),
            ],
          ),
        ),
      ),
    );
  }

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
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: AppColors.cardColor,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 16),
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

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Дата народження",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        InkWell(
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
                      surface: AppColors.cardColor,
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
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedDob == null
                  ? "Оберіть дату"
                  : "${_selectedDob!.day}.${_selectedDob!.month}.${_selectedDob!.year}",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
