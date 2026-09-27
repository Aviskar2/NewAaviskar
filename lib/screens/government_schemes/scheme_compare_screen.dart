import 'package:flutter/material.dart';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_service.dart';

class SchemeCompareScreen extends StatefulWidget {
  const SchemeCompareScreen({Key? key}) : super(key: key);

  @override
  State<SchemeCompareScreen> createState() => _SchemeCompareScreenState();
}

class _SchemeCompareScreenState extends State<SchemeCompareScreen> {
  final _service = SchemeService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final schemes = _service.compareSchemes;

    if (schemes.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compare_arrows_rounded,
                  size: 56, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('No schemes to compare',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text('Tap the compare icon on scheme cards to add up to 3 schemes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Compare (${schemes.length}/3)'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _service.clearCompare());
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabelColumn(theme),
            ...schemes.map((s) => _buildSchemeColumn(s, theme, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelColumn(ThemeData theme) {
    return Container(
      width: 120,
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          _labelRow('Category'),
          _labelRow('Level'),
          _labelRow('Ministry'),
          _labelRow('Income Limit'),
          _labelRow('Age Range'),
          _labelRow('Gender'),
          _labelRow('BPL Required'),
          _labelRow('SC/ST Only'),
          _labelRow('Farmer Only'),
          _labelRow('Student Only'),
          _labelRow('Disability'),
          _labelRow('Occupation'),
          _labelRow('Benefits'),
          _labelRow('Documents'),
        ],
      ),
    );
  }

  Widget _labelRow(String label) {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }

  Widget _buildSchemeColumn(GovernmentScheme scheme, ThemeData theme, bool isDark) {
    final elig = scheme.eligibility;
    return Container(
      width: 200,
      margin: const EdgeInsets.only(left: 8),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF2563EB).withValues(alpha: 0.1),
                const Color(0xFF7C3AED).withValues(alpha: 0.1),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(scheme.category.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text(scheme.shortName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4),
                Text(scheme.level == SchemeLevel.central ? 'Central' : 'State',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 4),

          _dataRow(scheme.category.label),
          _dataRow(scheme.level == SchemeLevel.central ? 'Central' : 'State'),
          _dataRow(scheme.ministry, maxLines: 2),
          _dataRow(elig.maxAnnualIncome != null ? 'Rs ${_formatIncome(elig.maxAnnualIncome!)}' : 'No limit'),
          _dataRow('${elig.minAge ?? 0} - ${elig.maxAge ?? 100} years'),
          _dataRow(_genderLabel(elig.gender)),
          _dataRow(elig.isBPLRequired ? 'Yes' : 'No'),
          _dataRow(elig.isSCSTRequired ? 'Yes' : 'No'),
          _dataRow(elig.isFarmerRequired ? 'Yes' : 'No'),
          _dataRow(elig.isStudentRequired ? 'Yes' : 'No'),
          _dataRow(elig.isDisabledRequired ? 'Yes' : 'No'),
          _dataRow(elig.occupationRequired ?? 'Any', maxLines: 2),
          _dataRow('${scheme.benefits.length} benefits', maxLines: 2),
          _dataRow('${scheme.documentsRequired.length} docs needed'),
        ],
      ),
    );
  }

  Widget _dataRow(String text, {int maxLines = 1}) {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, height: 1.3)),
    );
  }

  String _genderLabel(EligibilityGender g) {
    switch (g) {
      case EligibilityGender.all: return 'All';
      case EligibilityGender.male: return 'Male Only';
      case EligibilityGender.female: return 'Female Only';
      case EligibilityGender.transgender: return 'Transgender';
    }
  }

  String _formatIncome(double income) {
    if (income >= 100000) return '${(income / 100000).toStringAsFixed(1)} Lakh';
    return income.toStringAsFixed(0);
  }
}
