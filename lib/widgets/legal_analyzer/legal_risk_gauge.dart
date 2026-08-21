import 'package:flutter/material.dart';
import '../../core/legal/models/legal_finding.dart';

class LegalRiskGauge extends StatelessWidget {
  final double score; // 0..100
  final LegalRiskSeverity severity;

  const LegalRiskGauge({
    super.key,
    required this.score,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = severity.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Circular progress gauge
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 8,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${score.toInt()}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    '/100',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${severity.emoji} ${severity.displayName.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _riskDescription(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.3,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _riskDescription() {
    switch (severity) {
      case LegalRiskSeverity.high:
        return 'Multiple high-risk or potentially unenforceable terms detected. Strict negotiation recommended.';
      case LegalRiskSeverity.medium:
        return 'Notable one-sided clauses found. Review recommended before signing.';
      case LegalRiskSeverity.low:
        return 'Minor advisory notes. Terms generally conform to standard practice.';
      case LegalRiskSeverity.safe:
        return 'Standard fair terms aligned with Indian statutory guidelines.';
    }
  }
}
