import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_database.dart';

class ProfileSetupScreen extends StatefulWidget {
  final CitizenProfile initialProfile;
  final ValueChanged<CitizenProfile> onProfileSaved;

  const ProfileSetupScreen({
    super.key,
    required this.initialProfile,
    required this.onProfileSaved,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _incomeController;
  String _gender = 'Male';
  String _state = '';
  String _occupation = '';
  bool _isBPL = false;
  bool _isSCST = false;
  bool _isStudent = false;
  bool _isFarmer = false;
  bool _isDisabled = false;
  bool _isSeniorCitizen = false;
  bool _isWidow = false;
  bool _isMinority = false;

  static const List<String> _genders = ['Male', 'Female', 'Transgender'];

  static const List<String> _occupations = [
    'Student',
    'Farmer',
    'Street Vendor',
    'Rickshaw / Auto Driver',
    'Domestic Worker',
    'Construction Worker',
    'Factory Worker',
    'Daily Wage Labourer',
    'Small Business Owner',
    'Self-Employed / Freelancer',
    'Government Employee',
    'Private Sector Employee',
    'Teacher',
    'Healthcare Worker',
    'Driver (Taxi / Truck / Delivery)',
    'Tailor / Mechanic / Artisan',
    'Fisherman / Logger',
    'Transport Worker',
    'Housewife / Homemaker',
    'Retired',
    'Unemployed',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _ageController = TextEditingController(
        text: widget.initialProfile.age > 0 ? widget.initialProfile.age.toString() : '');
    _incomeController = TextEditingController(
        text: widget.initialProfile.annualIncome > 0
            ? widget.initialProfile.annualIncome.toStringAsFixed(0)
            : '');
    _gender = _genders.contains(widget.initialProfile.gender)
        ? widget.initialProfile.gender
        : 'Male';
    _state = SchemeDatabase.indianStates.contains(widget.initialProfile.state)
        ? widget.initialProfile.state
        : '';
    _occupation = _occupations.contains(widget.initialProfile.occupation)
        ? (widget.initialProfile.occupation ?? '')
        : '';
    _isBPL = widget.initialProfile.isBPL;
    _isSCST = widget.initialProfile.isSCST;
    _isStudent = widget.initialProfile.isStudent;
    _isFarmer = widget.initialProfile.isFarmer;
    _isDisabled = widget.initialProfile.isDisabled;
    _isSeniorCitizen = widget.initialProfile.isSeniorCitizen;
    _isWidow = widget.initialProfile.isWidow;
    _isMinority = widget.initialProfile.isMinority;
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProfile != oldWidget.initialProfile) {
      if (_genders.contains(widget.initialProfile.gender)) {
        _gender = widget.initialProfile.gender;
      }
      if (SchemeDatabase.indianStates.contains(widget.initialProfile.state)) {
        _state = widget.initialProfile.state;
      }
      if (_occupations.contains(widget.initialProfile.occupation)) {
        _occupation = widget.initialProfile.occupation!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('citizen_profile');
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      setState(() {
        _nameController.text = data['name'] ?? '';
        _ageController.text = (data['age'] ?? 0).toString();
        _incomeController.text = (data['annualIncome'] ?? 0).toStringAsFixed(0);
        final loadedGender = data['gender']?.toString();
        _gender = _genders.contains(loadedGender) ? loadedGender! : 'Male';
        final loadedState = data['state']?.toString();
        _state = SchemeDatabase.indianStates.contains(loadedState) ? loadedState! : '';
        final loadedOcc = data['occupation']?.toString();
        _occupation = _occupations.contains(loadedOcc) ? loadedOcc! : '';
        _isBPL = data['isBPL'] ?? false;
        _isSCST = data['isSCST'] ?? false;
        _isStudent = data['isStudent'] ?? false;
        _isFarmer = data['isFarmer'] ?? false;
        _isDisabled = data['isDisabled'] ?? false;
        _isSeniorCitizen = data['isSeniorCitizen'] ?? false;
        _isWidow = data['isWidow'] ?? false;
        _isMinority = data['isMinority'] ?? false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = CitizenProfile(
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text) ?? 0,
      gender: _gender,
      annualIncome: double.tryParse(_incomeController.text) ?? 0,
      state: _state,
      occupation: _occupation.isEmpty ? null : _occupation,
      isBPL: _isBPL,
      isSCST: _isSCST,
      isStudent: _isStudent,
      isFarmer: _isFarmer,
      isDisabled: _isDisabled,
      isSeniorCitizen: _isSeniorCitizen,
      isWidow: _isWidow,
      isMinority: _isMinority,
      isWoman: _gender == 'Female',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('citizen_profile', jsonEncode({
      'name': profile.name,
      'age': profile.age,
      'gender': profile.gender,
      'annualIncome': profile.annualIncome,
      'state': profile.state,
      'occupation': profile.occupation,
      'isBPL': profile.isBPL,
      'isSCST': profile.isSCST,
      'isStudent': profile.isStudent,
      'isFarmer': profile.isFarmer,
      'isDisabled': profile.isDisabled,
      'isSeniorCitizen': profile.isSeniorCitizen,
      'isWidow': profile.isWidow,
      'isMinority': profile.isMinority,
    }));

    widget.onProfileSaved(profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved! Schemes are now personalized.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Placeholder
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_rounded,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Age and Gender
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _ageController,
                    label: 'Age',
                    icon: Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final age = int.tryParse(v);
                      if (age == null || age < 1 || age > 120) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('gender_$_gender'),
                    isExpanded: true,
                    initialValue: _genders.contains(_gender) ? _gender : _genders.first,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: const Icon(Icons.wc_rounded, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    items: _genders.map((g) {
                      return DropdownMenuItem(
                        value: g,
                        child: Text(g, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _gender = v);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Annual Income
            _buildTextField(
              controller: _incomeController,
              label: 'Annual Family Income (Rs)',
              icon: Icons.currency_rupee_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // State
            DropdownButtonFormField<String>(
              key: ValueKey('state_$_state'),
              isExpanded: true,
              initialValue: SchemeDatabase.indianStates.contains(_state) ? _state : null,
              decoration: InputDecoration(
                labelText: 'State / UT',
                prefixIcon: const Icon(Icons.location_on_rounded, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              items: SchemeDatabase.indianStates.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (v) => setState(() => _state = v ?? ''),
              validator: (v) => v == null || v.isEmpty ? 'Select your state' : null,
            ),
            const SizedBox(height: 16),

            // Occupation
            DropdownButtonFormField<String>(
              key: ValueKey('occupation_$_occupation'),
              isExpanded: true,
              initialValue: _occupations.contains(_occupation) ? _occupation : null,
              decoration: InputDecoration(
                labelText: 'Occupation',
                prefixIcon: const Icon(Icons.work_rounded, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              items: _occupations.map((o) {
                return DropdownMenuItem(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (v) => setState(() => _occupation = v ?? ''),
            ),
            const SizedBox(height: 20),

            // Category Checkboxes
            Text('Category (if applicable)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCheckChip('BPL (Below Poverty Line)', _isBPL,
                    (v) => setState(() => _isBPL = v)),
                _buildCheckChip('SC / ST', _isSCST,
                    (v) => setState(() => _isSCST = v)),
              ],
            ),
            const SizedBox(height: 16),

            Text('Status',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCheckChip('Student', _isStudent,
                    (v) => setState(() => _isStudent = v)),
                _buildCheckChip('Farmer', _isFarmer,
                    (v) => setState(() => _isFarmer = v)),
                _buildCheckChip('Senior Citizen (60+)', _isSeniorCitizen,
                    (v) => setState(() => _isSeniorCitizen = v)),
                _buildCheckChip('Person with Disability', _isDisabled,
                    (v) => setState(() => _isDisabled = v)),
                _buildCheckChip('Widow', _isWidow,
                    (v) => setState(() => _isWidow = v)),
                _buildCheckChip('Minority', _isMinority,
                    (v) => setState(() => _isMinority = v)),
              ],
            ),
            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save & Match Schemes',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildCheckChip(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? const Color(0xFF2563EB)
                : Theme.of(context).colorScheme.outlineVariant,
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: value ? const Color(0xFF2563EB) : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: value
                    ? const Color(0xFF2563EB)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
