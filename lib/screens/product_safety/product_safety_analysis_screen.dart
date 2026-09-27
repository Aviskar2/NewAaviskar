import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_safety_model.dart';
import '../../utils/url_launcher_util.dart';

/// Interactive Report Dashboard for Product, Food Standards (FSSAI), Barcode & Expiry.
class ProductSafetyAnalysisScreen extends StatefulWidget {
  final ProductSafetyReport report;

  const ProductSafetyAnalysisScreen({
    Key? key,
    required this.report,
  }) : super(key: key);

  @override
  State<ProductSafetyAnalysisScreen> createState() => _ProductSafetyAnalysisScreenState();
}

class _ProductSafetyAnalysisScreenState extends State<ProductSafetyAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = widget.report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product & Food Safety Report'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share safety summary',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildShareReport(r)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Safety summary copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: '⏳ Expiry'),
            Tab(text: '🏢 FSSAI'),
            Tab(text: '🍎 Nutrition'),
            Tab(text: '🧪 Additives'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Master Verdict Banner
          _VerdictBanner(report: r, isDark: isDark, theme: theme),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SummaryTab(report: r, isDark: isDark, theme: theme),
                _ExpiryTab(expiry: r.expiryAnalysis, isDark: isDark, theme: theme),
                _FssaiTab(fssai: r.fssaiVerification, isDark: isDark, theme: theme),
                _NutritionTab(nutrition: r.nutritionalAnalysis, isDark: isDark, theme: theme),
                _AdditivesTab(ingredients: r.ingredientAnalysis, isDark: isDark, theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildShareReport(ProductSafetyReport r) {
    final buf = StringBuffer();
    buf.writeln('=== PRODUCT & FOOD SAFETY REPORT ===');
    buf.writeln('Verdict: ${r.overallVerdict.emoji} ${r.overallVerdict.displayName} (${r.safetyScore.toInt()}/100)');
    if (r.barcodeInfo != null) {
      buf.writeln('Barcode: ${r.barcodeInfo!.barcode} (${r.barcodeInfo!.countryOfOrigin})');
    }
    buf.writeln('Expiry: ${r.expiryAnalysis.status.displayName}');
    if (r.fssaiVerification != null) {
      buf.writeln('FSSAI: ${r.fssaiVerification!.rawLicenseNumber} (${r.fssaiVerification!.stateName ?? "India"})');
    }
    buf.writeln('\n--- FINDINGS ---');
    for (final f in r.findings) {
      buf.writeln('• [${f.category}] ${f.title}: ${f.explanation}');
    }
    return buf.toString();
  }
}

// ─── Header Banner ────────────────────────────────────────────────────────────

class _VerdictBanner extends StatelessWidget {
  final ProductSafetyReport report;
  final bool isDark;
  final ThemeData theme;

  const _VerdictBanner({
    required this.report,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = report.overallVerdict.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Text(report.overallVerdict.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.overallVerdict.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.barcodeInfo?.brandName != null
                      ? '${report.barcodeInfo!.brandName} · ${report.barcodeInfo!.category ?? "Packaged Food"}'
                      : 'FSSAI & Legal Metrology Audited',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${report.safetyScore.toInt()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  'SAFETY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Tab ──────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final ProductSafetyReport report;
  final bool isDark;
  final ThemeData theme;

  const _SummaryTab({
    required this.report,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final r = report;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Barcode / Origin Card
        if (r.barcodeInfo != null)
          _CardContainer(
            title: '🏷️ Barcode & Product Identification',
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.barcodeInfo!.barcode,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const Spacer(),
                    if (r.barcodeInfo!.isMadeInIndia)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🇮🇳 Made in India (890)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Origin: ${r.barcodeInfo!.countryOfOrigin}'
                  '${r.barcodeInfo!.brandName != null ? " · ${r.barcodeInfo!.brandName}" : ""}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

        // Quick Highlights
        _CardContainer(
          title: '🛡️ Safety Verification Breakdown',
          isDark: isDark,
          child: Column(
            children: [
              _StatusTile(
                icon: Icons.calendar_today_rounded,
                title: 'Expiry & Freshness',
                subtitle: r.expiryAnalysis.status.displayName,
                badge: r.expiryAnalysis.daysRemaining != null
                    ? '${r.expiryAnalysis.daysRemaining} days'
                    : 'N/A',
                badgeColor: r.expiryAnalysis.status == ExpiryStatus.expired ? Colors.red : Colors.green,
              ),
              const Divider(height: 16),
              _StatusTile(
                icon: Icons.verified_user_rounded,
                title: 'FSSAI License',
                subtitle: r.fssaiVerification?.statusMessage ?? 'No 14-digit FSSAI number detected',
                badge: r.fssaiVerification?.isValid == true ? 'Valid' : 'Check',
                badgeColor: r.fssaiVerification?.isValid == true ? Colors.green : Colors.orange,
              ),
              const Divider(height: 16),
              _StatusTile(
                icon: Icons.restaurant_rounded,
                title: 'Food Standards',
                subtitle: r.ingredientAnalysis.isNonVegetarian
                    ? 'Non-Vegetarian Product'
                    : (r.ingredientAnalysis.isVegetarian ? '100% Vegetarian (Green Dot)' : 'Dietary info extracted'),
                badge: r.ingredientAnalysis.isVegetarian ? '🟢 Veg' : (r.ingredientAnalysis.isNonVegetarian ? '🔴 Non-Veg' : 'Standard'),
                badgeColor: r.ingredientAnalysis.isVegetarian ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),

        // Findings List
        const SizedBox(height: 8),
        Text('STATUTORY FINDINGS & ALERTS', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...r.findings.map((f) => _FindingCard(finding: f, isDark: isDark, theme: theme)),
      ],
    );
  }
}

// ─── Expiry Tab ───────────────────────────────────────────────────────────────

class _ExpiryTab extends StatelessWidget {
  final ExpiryAnalysis expiry;
  final bool isDark;
  final ThemeData theme;

  const _ExpiryTab({
    required this.expiry,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CardContainer(
          title: '⏳ Expiry & Shelf-Life Assessment',
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(expiry.status.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expiry.status.displayName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        if (expiry.daysRemaining != null)
                          Text(
                            expiry.daysRemaining! >= 0
                                ? '${expiry.daysRemaining} days remaining until expiry'
                                : 'Expired ${expiry.daysRemaining!.abs()} days ago',
                            style: TextStyle(
                              fontSize: 13,
                              color: expiry.daysRemaining! >= 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Progress Bar
              if (expiry.expiryDate != null) ...[
                const Text('Shelf-Life Consumed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: expiry.shelfLifeConsumedPercentage,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    expiry.status == ExpiryStatus.expired
                        ? Colors.red
                        : (expiry.status == ExpiryStatus.expiringSoon ? Colors.orange : Colors.green),
                  ),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 16),
              ],

              // Dates Table
              _InfoRow('Manufacturing Date (Mfg)', expiry.manufacturingDate != null
                  ? '${expiry.manufacturingDate!.day}/${expiry.manufacturingDate!.month}/${expiry.manufacturingDate!.year}'
                  : 'Not explicitly specified'),
              _InfoRow('Expiry Date (Exp)', expiry.expiryDate != null
                  ? '${expiry.expiryDate!.day}/${expiry.expiryDate!.month}/${expiry.expiryDate!.year}'
                  : 'Not explicitly specified'),
              if (expiry.bestBeforePhrase != null)
                _InfoRow('Best Before Rule', expiry.bestBeforePhrase!),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _CardContainer(
          title: '📜 Consumer Protection Advisory',
          isDark: isDark,
          child: Text(
            'Under the Consumer Protection Act 2019 and FSSAI Packaging Regulations, '
            'selling food past its expiry date is an unfair trade practice. Consumers are entitled to '
            'a full replacement or refund from the seller.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ─── FSSAI Tab ────────────────────────────────────────────────────────────────

class _FssaiTab extends StatelessWidget {
  final FssaiVerification? fssai;
  final bool isDark;
  final ThemeData theme;

  const _FssaiTab({
    this.fssai,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (fssai == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'No 14-Digit FSSAI License Detected',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please scan the back or bottom panel of the food packaging where the FSSAI logo and 14-digit registration number are printed.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CardContainer(
          title: '🏢 FSSAI 14-Digit License Decoder',
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: fssai!.isValid ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: fssai!.isValid ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      fssai!.isValid ? Icons.verified_rounded : Icons.error_outline_rounded,
                      color: fssai!.isValid ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fssai!.rawLicenseNumber,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                          Text(
                            fssai!.licenseType.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: fssai!.isValid ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoRow('License Type (Digit 1)', fssai!.licenseType.displayName),
              _InfoRow('State Jurisdiction (Digits 2-3)', '${fssai!.stateCode ?? "N/A"} · ${fssai!.stateName ?? "Unknown"}'),
              _InfoRow('Enrollment Year (Digits 4-5)', fssai!.registrationYear ?? 'N/A'),
              _InfoRow('Registrar / Authority (Digits 6-8)', fssai!.enrollingAuthority ?? 'N/A'),
              _InfoRow('Manufacturer Serial (Digits 9-14)', fssai!.manufacturerSerialNumber ?? 'N/A'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            UrlLauncherUtil.launch('https://foscos.fssai.gov.in');
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Verify on Official FSSAI FoSCoS Portal'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

// ─── Nutrition Tab ────────────────────────────────────────────────────────────

class _NutritionTab extends StatelessWidget {
  final NutritionalAnalysis nutrition;
  final bool isDark;
  final ThemeData theme;

  const _NutritionTab({
    required this.nutrition,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Traffic Light HFSS Indicators
        _CardContainer(
          title: '🍎 FSSAI Traffic-Light Nutrition Meters',
          isDark: isDark,
          child: Column(
            children: [
              _NutrientMeter(
                label: 'Total / Added Sugars',
                value: nutrition.totalSugarGrams != null ? '${nutrition.totalSugarGrams}g' : 'N/A',
                isHigh: nutrition.isHighSugar,
                limitDesc: 'Limit: < 10g / 100g',
              ),
              const SizedBox(height: 12),
              _NutrientMeter(
                label: 'Sodium (Salt)',
                value: nutrition.sodiumMg != null ? '${nutrition.sodiumMg}mg' : 'N/A',
                isHigh: nutrition.isHighSodium,
                limitDesc: 'Limit: < 400mg / 100g',
              ),
              const SizedBox(height: 12),
              _NutrientMeter(
                label: 'Saturated Fat',
                value: nutrition.saturatedFatGrams != null ? '${nutrition.saturatedFatGrams}g' : 'N/A',
                isHigh: nutrition.isHighSaturatedFat,
                limitDesc: 'Limit: < 5g / 100g',
              ),
              const SizedBox(height: 12),
              _NutrientMeter(
                label: 'Trans Fat',
                value: nutrition.transFatGrams != null ? '${nutrition.transFatGrams}g' : '0.0g',
                isHigh: nutrition.hasExcessTransFat,
                limitDesc: 'FSSAI Cap: < 0.2g',
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Full Facts
        _CardContainer(
          title: '📊 Nutrition Facts Table (Extracted)',
          isDark: isDark,
          child: Column(
            children: [
              if (nutrition.energyKcal != null) _InfoRow('Energy / Calories', '${nutrition.energyKcal} kcal'),
              if (nutrition.proteinGrams != null) _InfoRow('Protein', '${nutrition.proteinGrams} g'),
              if (nutrition.totalCarbsGrams != null) _InfoRow('Carbohydrates', '${nutrition.totalCarbsGrams} g'),
              if (nutrition.totalSugarGrams != null) _InfoRow('Total Sugar', '${nutrition.totalSugarGrams} g'),
              if (nutrition.addedSugarGrams != null) _InfoRow('Added Sugar', '${nutrition.addedSugarGrams} g'),
              if (nutrition.totalFatGrams != null) _InfoRow('Total Fat', '${nutrition.totalFatGrams} g'),
              if (nutrition.sodiumMg != null) _InfoRow('Sodium', '${nutrition.sodiumMg} mg'),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Additives Tab ────────────────────────────────────────────────────────────

class _AdditivesTab extends StatelessWidget {
  final IngredientStandardsAnalysis ingredients;
  final bool isDark;
  final ThemeData theme;

  const _AdditivesTab({
    required this.ingredients,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Detected INS Additives
        _CardContainer(
          title: '🧪 Detected Food Additives & INS Codes',
          isDark: isDark,
          child: ingredients.detectedAdditives.isEmpty
              ? const Text('No harmful or high-risk INS additives detected in label text.')
              : Column(
                  children: ingredients.detectedAdditives.map((a) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.science_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 14),

        // Allergens
        _CardContainer(
          title: '⚠️ Allergen Warnings',
          isDark: isDark,
          child: ingredients.detectedAllergens.isEmpty
              ? const Text('No common allergen declarations detected.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ingredients.detectedAllergens.map((allergen) {
                    return Chip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                      label: Text(allergen, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 14),

        // Health Concerns (Palm Oil / Sweeteners)
        if (ingredients.healthConcerns.isNotEmpty)
          _CardContainer(
            title: '🔍 Ingredient Quality Notes',
            isDark: isDark,
            child: Column(
              children: ingredients.healthConcerns.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─── Shared UI Helpers ────────────────────────────────────────────────────────

class _CardContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDark;

  const _CardContainer({
    required this.title,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;

  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: badgeColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _FindingCard extends StatelessWidget {
  final ProductSafetyFinding finding;
  final bool isDark;
  final ThemeData theme;

  const _FindingCard({
    required this.finding,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = finding.severity.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(finding.severity.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '[${finding.category}] ${finding.title}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(finding.explanation, style: const TextStyle(fontSize: 13, height: 1.3)),
          if (finding.recommendation != null) ...[
            const SizedBox(height: 6),
            Text('👉 Action: ${finding.recommendation!}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          if (finding.statutoryReference != null) ...[
            const SizedBox(height: 4),
            Text('⚖️ Rule: ${finding.statutoryReference!}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class _NutrientMeter extends StatelessWidget {
  final String label;
  final String value;
  final bool isHigh;
  final String limitDesc;

  const _NutrientMeter({
    required this.label,
    required this.value,
    required this.isHigh,
    required this.limitDesc,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHigh ? Colors.red : Colors.green;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(limitDesc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isHigh ? 'HIGH ⚠️' : 'OK ✅',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
