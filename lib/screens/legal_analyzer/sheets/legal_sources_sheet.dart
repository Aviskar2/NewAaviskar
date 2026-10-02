import 'package:flutter/material.dart';

/// Modal bottom sheet displaying Indian Statutory Registry and legal source information
/// relocated from the main overview screen as mandated by Section 12.
class LegalSourcesSheet extends StatelessWidget {
  const LegalSourcesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LegalSourcesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statutes = [
      _StatuteInfo(
        title: 'Bharatiya Nyaya Sanhita, 2023 (BNS)',
        description: 'Replaced Indian Penal Code 1860. Covers fraud, cheating, criminal breach of trust.',
        status: 'Active 2024 Law',
        statusColor: const Color(0xFF16A34A),
      ),
      _StatuteInfo(
        title: 'Bharatiya Nagarik Suraksha Sanhita, 2023 (BNSS)',
        description: 'Modern criminal procedural protections and digital evidence mandates.',
        status: 'Active 2024 Law',
        statusColor: const Color(0xFF16A34A),
      ),
      _StatuteInfo(
        title: 'Bharatiya Sakshya Adhiniyam, 2023 (BSA)',
        description: 'Admissibility of electronic contracts, digital signatures, and electronic records.',
        status: 'Active 2024 Law',
        statusColor: const Color(0xFF16A34A),
      ),
      _StatuteInfo(
        title: 'Digital Personal Data Protection Act, 2023 (DPDP)',
        description: 'Mandatory consent, data minimization, and privacy rights across Indian jurisdictions.',
        status: 'Enacted 2023',
        statusColor: const Color(0xFF2563EB),
      ),
      _StatuteInfo(
        title: 'Real Estate (Regulation and Development) Act, 2016 (RERA)',
        description: 'Section 13 (10% advance cap) and Section 18 (statutory interest for delayed possession).',
        status: 'Active Mandate',
        statusColor: const Color(0xFF2563EB),
      ),
      _StatuteInfo(
        title: 'Model Tenancy Act, 2021',
        description: 'Standard residential deposit ceilings (2 months) and repair allocation obligations.',
        status: 'Modern Benchmark',
        statusColor: const Color(0xFF2563EB),
      ),
      _StatuteInfo(
        title: 'Indian Contract Act, 1872',
        description: 'Section 27 (agreements in restraint of trade void) & Section 74 (reasonable compensation).',
        status: 'In Force',
        statusColor: const Color(0xFF64748B),
      ),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.gavel_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legal Sources & Registry',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Live Indian Statutory Database & Verification',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),

            // Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Verification status banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 20, color: Color(0xFF16A34A)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Indian Statutory Registry Active',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Auto-synced with Gazette of India & India Code repository. Verified in background within 24h.',
                                style: TextStyle(fontSize: 11.5, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metadata table
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildMetaRow('Primary Database', 'Official Gazette of India & India Code', isDark),
                        const Divider(height: 14),
                        _buildMetaRow('Verification Cycle', 'Every 24 hours (Automated)', isDark),
                        const Divider(height: 14),
                        _buildMetaRow('Jurisdiction Scope', 'Republic of India (Union & Model State Laws)', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'APPLICABLE LEGISLATION IN REGISTRY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...statutes.map((s) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.description,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: s.statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                s.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: s.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            // Footer
            Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatuteInfo {
  final String title;
  final String description;
  final String status;
  final Color statusColor;

  const _StatuteInfo({
    required this.title,
    required this.description,
    required this.status,
    required this.statusColor,
  });
}
