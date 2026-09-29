import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/medicine_safety_model.dart';
import '../../utils/url_launcher_util.dart';

/// Interactive Report Dashboard for Medicine Safety, Drug Schedules, Mfg License & Jan Aushadhi Generic Savings.
class MedicineAnalysisScreen extends StatefulWidget {
  final MedicineSafetyReport report;

  const MedicineAnalysisScreen({
    super.key,
    required this.report,
  });

  @override
  State<MedicineAnalysisScreen> createState() => _MedicineAnalysisScreenState();
}

class _MedicineAnalysisScreenState extends State<MedicineAnalysisScreen>
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
        title: const Text('Medicine Safety & Generic Report'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Medicine Report',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildShareReport(r)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Medicine safety summary copied to clipboard'),
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
            Tab(text: '⚠️ Schedule & Warning'),
            Tab(text: '💰 Jan Aushadhi Savings'),
            Tab(text: '⏳ Batch & Expiry'),
            Tab(text: '🏢 Mfg License'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Master Verdict Banner
          _VerdictBanner(report: r, isDark: isDark, theme: theme),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SummaryTab(report: r, isDark: isDark, theme: theme),
                _ScheduleTab(report: r, isDark: isDark, theme: theme),
                _GenericSavingsTab(comparison: r.genericComparison, isDark: isDark, theme: theme),
                _BatchExpiryTab(batchExpiry: r.batchExpiry, isDark: isDark, theme: theme),
                _LicenseTab(license: r.licenseVerification, isDark: isDark, theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildShareReport(MedicineSafetyReport r) {
    final buf = StringBuffer();
    buf.writeln('=== MEDICINE PHARMA SAFETY REPORT ===');
    buf.writeln('Verdict: ${r.overallVerdict.emoji} ${r.overallVerdict.displayName} (${r.safetyScore.toInt()}/100)');
    buf.writeln('Schedule: ${r.schedule.displayName}');
    if (r.brandName != null) buf.writeln('Brand: ${r.brandName}');
    if (r.activeIngredients.isNotEmpty) buf.writeln('Active Salts: ${r.activeIngredients.join(", ")}');
    if (r.genericComparison != null) {
      buf.writeln('Jan Aushadhi Generic Savings: Save ${r.genericComparison!.savingsPercentage.toInt()}% (Save ₹${r.genericComparison!.amountSaved.toStringAsFixed(0)})');
    }
    buf.writeln('Expiry: ${r.batchExpiry.isExpired ? "EXPIRED 🔴" : "Valid ✅ (${r.batchExpiry.daysRemaining ?? 'N/A'} days left)"}');
    buf.writeln('\n--- STATUTORY FINDINGS ---');
    for (final f in r.findings) {
      buf.writeln('• [${f.category}] ${f.title}: ${f.explanation}');
    }
    return buf.toString();
  }
}

// ─── Header Verdict Banner ───────────────────────────────────────────────────

class _VerdictBanner extends StatelessWidget {
  final MedicineSafetyReport report;
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
                Row(
                  children: [
                    Text(
                      report.overallVerdict.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: report.schedule.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: report.schedule.color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        report.schedule.badgeSymbol,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: report.schedule.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  report.brandName != null
                      ? '${report.brandName} · ${report.activeIngredients.take(2).join(" + ")}'
                      : (report.activeIngredients.isNotEmpty
                          ? report.activeIngredients.join(" + ")
                          : 'Drugs & Cosmetics Act Audited'),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
  final MedicineSafetyReport report;
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
        // Jan Aushadhi Savings Hero Card (if available)
        if (r.genericComparison != null)
          _SavingsHeroCard(comparison: r.genericComparison!, isDark: isDark),

        // Quick Highlights
        _CardContainer(
          title: '💊 Pharmaceutical Verification Highlights',
          isDark: isDark,
          child: Column(
            children: [
              _MedStatusTile(
                icon: Icons.medical_services_rounded,
                title: 'Drug Schedule',
                subtitle: r.schedule.displayName,
                badge: r.schedule.badgeSymbol,
                badgeColor: r.schedule.color,
              ),
              const Divider(height: 16),
              _MedStatusTile(
                icon: Icons.calendar_today_rounded,
                title: 'Batch & Expiry',
                subtitle: r.batchExpiry.isExpired
                    ? 'EXPIRED — Do not consume'
                    : 'Valid shelf life (${r.batchExpiry.daysRemaining ?? "N/A"} days left)',
                badge: r.batchExpiry.isExpired ? 'Expired' : 'Valid',
                badgeColor: r.batchExpiry.isExpired ? Colors.red : Colors.green,
              ),
              const Divider(height: 16),
              _MedStatusTile(
                icon: Icons.verified_user_rounded,
                title: 'Manufacturing License',
                subtitle: r.licenseVerification?.statusMessage ?? 'Mfg license check offline',
                badge: r.licenseVerification?.isValid == true ? 'Licensed' : 'Unconfirmed',
                badgeColor: r.licenseVerification?.isValid == true ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ),

        // Storage Instructions
        if (r.storageInstructions != null)
          _CardContainer(
            title: '🌡️ Storage & Handling Guidelines',
            isDark: isDark,
            child: Row(
              children: [
                const Icon(Icons.thermostat_rounded, color: Colors.blue, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(r.storageInstructions!, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),

        // Statutory Findings
        const SizedBox(height: 8),
        Text('STATUTORY FINDINGS & AUDIT NOTES', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...r.findings.map((f) => _MedicineFindingCard(finding: f, isDark: isDark, theme: theme)),
      ],
    );
  }
}

// ─── Schedule & Warning Tab ───────────────────────────────────────────────────

class _ScheduleTab extends StatelessWidget {
  final MedicineSafetyReport report;
  final bool isDark;
  final ThemeData theme;

  const _ScheduleTab({
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
        // Statutory Warning Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: r.schedule.color.withValues(alpha: isDark ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: r.schedule.color, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: r.schedule.color, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.schedule.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: r.schedule.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                r.scheduleWarningText,
                style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Regulatory Guidance
        _CardContainer(
          title: '📜 Statutory Schedule Details (Drugs & Cosmetics Rules 1945)',
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.schedule == DrugSchedule.scheduleH1) ...[
                const Text('• Schedule H1 Mandate: The chemist must record the date of dispensing, patient name, prescribing doctor, and drug quantity in a separate register retained for at least 3 years.'),
                const SizedBox(height: 8),
                const Text('• Red Warning Symbol: Under Rule 97, packaging must feature a distinct red border box warning on the left top corner.'),
              ] else if (r.schedule == DrugSchedule.scheduleH) ...[
                const Text('• Schedule H Mandate: To be sold by retail strictly on the prescription of a Registered Medical Practitioner (RMP).'),
              ] else if (r.schedule == DrugSchedule.scheduleX) ...[
                const Text('• Schedule X Mandate: Controlled psychotropic/narcotic formulation. Requires duplicate prescription and double-lock storage.'),
              ] else ...[
                const Text('• Over-The-Counter: Permitted for general consumer purchase under approved dosage instructions.'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Jan Aushadhi Generic Savings Tab ─────────────────────────────────────────

class _GenericSavingsTab extends StatelessWidget {
  final JanAushadhiGenericComparison? comparison;
  final bool isDark;
  final ThemeData theme;

  const _GenericSavingsTab({
    this.comparison,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (comparison == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.health_and_safety_rounded, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'General Salt Formulation',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask your local pharmacist for a generic equivalent under the Pradhan Mantri Bhartiya Janaushadhi Pariyojana (PMBJP) to save up to 50-80% on costs.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final c = comparison!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SavingsHeroCard(comparison: c, isDark: isDark),

        const SizedBox(height: 16),

        _CardContainer(
          title: '⚖️ Exact Molecule & Salt Comparison',
          isDark: isDark,
          child: Column(
            children: [
              _MedInfoRow('Active Generic Salt', c.genericSalt),
              _MedInfoRow('Strength / Dosage', c.strength),
              _MedInfoRow('Scanned Brand Name', c.brandName),
              _MedInfoRow('PMBJP Product Code', c.pmbjpCode),
              const Divider(height: 16),
              _MedInfoRow('Branded Estimated MRP', '₹${c.estimatedBrandedMrp.toStringAsFixed(0)}'),
              _MedInfoRow('Jan Aushadhi Generic Price', '₹${c.janAushadhiPrice.toStringAsFixed(0)}'),
              _MedInfoRow('You Save Per Pack', '₹${c.amountSaved.toStringAsFixed(0)} (${c.savingsPercentage.toInt()}%)'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: () {
            UrlLauncherUtil.launch('http://janaushadhi.gov.in');
          },
          icon: const Icon(Icons.storefront_rounded),
          label: const Text('Find Nearest Jan Aushadhi Kendra'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

// ─── Batch & Expiry Tab ───────────────────────────────────────────────────────

class _BatchExpiryTab extends StatelessWidget {
  final MedicineBatchExpiry batchExpiry;
  final bool isDark;
  final ThemeData theme;

  const _BatchExpiryTab({
    required this.batchExpiry,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CardContainer(
          title: '⏳ Medicine Batch & Shelf-Life Assessment',
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    batchExpiry.isExpired ? Icons.cancel_rounded : Icons.check_circle_rounded,
                    color: batchExpiry.isExpired ? Colors.red : Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batchExpiry.isExpired
                              ? 'EXPIRED MEDICINE — HIGH RISK'
                              : 'Valid Therapeutic Potency',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: batchExpiry.isExpired ? Colors.red : Colors.green,
                          ),
                        ),
                        if (batchExpiry.daysRemaining != null)
                          Text(
                            batchExpiry.daysRemaining! >= 0
                                ? '${batchExpiry.daysRemaining} days left until expiry'
                                : 'Expired ${batchExpiry.daysRemaining!.abs()} days ago',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MedInfoRow('Batch Number (B.No.)', batchExpiry.batchNumber ?? 'Not detected'),
              _MedInfoRow('Manufacturing Date (Mfg)', batchExpiry.manufacturingDate != null
                  ? '${batchExpiry.manufacturingDate!.day}/${batchExpiry.manufacturingDate!.month}/${batchExpiry.manufacturingDate!.year}'
                  : 'Not specified'),
              _MedInfoRow('Expiry Date (Exp)', batchExpiry.expiryDate != null
                  ? '${batchExpiry.expiryDate!.day}/${batchExpiry.expiryDate!.month}/${batchExpiry.expiryDate!.year}'
                  : 'Not specified'),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _CardContainer(
          title: '⚠️ Health Safety Notice on Expired Drugs',
          isDark: isDark,
          child: const Text(
            'Under Rule 65 of Drugs and Cosmetics Rules, selling or consuming expired medicine is strictly prohibited. '
            'Expired medicines may suffer chemical degradation, lose therapeutic efficacy, or produce harmful toxic by-products.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ─── Mfg License Tab ──────────────────────────────────────────────────────────

class _LicenseTab extends StatelessWidget {
  final DrugLicenseVerification? license;
  final bool isDark;
  final ThemeData theme;

  const _LicenseTab({
    this.license,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (license == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'No Mfg. Lic. No. Detected',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please scan the flap or bottom of the medicine pack where the state manufacturing license number is printed.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final lic = license!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CardContainer(
          title: '🏢 State Drug Licensing Authority Verification',
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lic.rawLicenseNumber,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          Text(
                            lic.formType ?? 'Form 25 Drug License',
                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _MedInfoRow('Licensing Authority', lic.stateAuthority ?? 'State FDA'),
              _MedInfoRow('State Code', lic.stateCode ?? 'General State Authority'),
              _MedInfoRow('Regulatory Compliance', 'Drugs & Cosmetics Rules 1945'),
            ],
          ),
        ),

        const SizedBox(height: 14),

        FilledButton.icon(
          onPressed: () {
            UrlLauncherUtil.launch('https://cdsco.gov.in');
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Verify on CDSCO National Portal'),
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

// ─── Shared UI Helpers ────────────────────────────────────────────────────────

class _SavingsHeroCard extends StatelessWidget {
  final JanAushadhiGenericComparison comparison;
  final bool isDark;

  const _SavingsHeroCard({
    required this.comparison,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Jan Aushadhi Generic Savings',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SAVE ${comparison.savingsPercentage.toInt()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Branded MRP: ₹${comparison.estimatedBrandedMrp.toStringAsFixed(0)} ➔ Jan Aushadhi: ₹${comparison.janAushadhiPrice.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Save ₹${comparison.amountSaved.toStringAsFixed(0)} per pack with identical active generic salt (${comparison.genericSalt}).',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }
}

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

class _MedStatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;

  const _MedStatusTile({
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

class _MedicineFindingCard extends StatelessWidget {
  final MedicineFinding finding;
  final bool isDark;
  final ThemeData theme;

  const _MedicineFindingCard({
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
            Text('⚖️ Law: ${finding.statutoryReference!}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class _MedInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _MedInfoRow(this.label, this.value);

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
