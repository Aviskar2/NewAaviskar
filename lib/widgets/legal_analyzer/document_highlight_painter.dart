import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/legal/models/legal_finding.dart';

/// Paints precise, translucent document highlight overlays on rendered pages (Sections 63, 64, 65, 74, 76).
///
/// Features:
/// - Discrete multi-line rectangle painting (Section 63) so margins and unrelated text are not highlighted.
/// - Translucent severity overlays (Section 64): Critical/High (red/pink), Medium (amber), Low (blue).
/// - Non-distracting subtle left accent border and underlines (Section 65).
/// - 1-time pulse animation support (Section 76).
/// - Direct coordinate transformation from normalized (0.0 to 1.0) coordinates (Section 74).
class DocumentHighlightPainter extends CustomPainter {
  final List<LegalFinding> findings;
  final String? selectedFindingId;
  final int pageIndex;
  final double pulseProgress; // 0.0 to 1.0 for single-shot pulse (Section 76)
  final LegalRiskSeverity? severityFilter; // Optional filter (Section 77)

  DocumentHighlightPainter({
    required this.findings,
    this.selectedFindingId,
    required this.pageIndex,
    this.pulseProgress = 0.0,
    this.severityFilter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final finding in findings) {
      if (finding.pageIndex != pageIndex) continue;
      if (severityFilter != null && finding.severity != severityFilter) continue;

      final isSelected = finding.id == selectedFindingId;
      final highlight = finding.highlight;

      // Skip unmapped findings (Section 81)
      if (highlight != null && !highlight.hasValidLocation) continue;

      // Extract discrete line rectangles (Section 63)
      final List<Rect> absoluteRects = [];
      if (highlight != null && highlight.rectangles.isNotEmpty) {
        for (final r in highlight.rectangles) {
          absoluteRects.add(r.toRect(size));
        }
      } else if (finding.boundingBox != null) {
        absoluteRects.add(finding.boundingBox!.toAbsoluteRect(size));
      }

      if (absoluteRects.isEmpty) continue;

      // Color selection per Section 64 (translucent overlays)
      final Color baseColor;
      switch (finding.severity) {
        case LegalRiskSeverity.high:
          baseColor = const Color(0xFFDC2626); // Red/pink
          break;
        case LegalRiskSeverity.medium:
          baseColor = const Color(0xFFD97706); // Amber/yellow
          break;
        case LegalRiskSeverity.low:
        case LegalRiskSeverity.safe:
          baseColor = const Color(0xFF2563EB); // Blue/gray
          break;
      }

      // Compute pulse effect (Section 76: brief 1-time pulse when selected)
      final double pulseFactor = isSelected && pulseProgress > 0.0
          ? math.sin(pulseProgress * math.pi) * 0.20
          : 0.0;

      final double fillAlpha = (isSelected ? 0.28 : 0.16) + pulseFactor;
      final double strokeAlpha = (isSelected ? 0.90 : 0.65) + pulseFactor;

      final fillPaint = Paint()
        ..color = baseColor.withValues(alpha: fillAlpha.clamp(0.10, 0.50))
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = baseColor.withValues(alpha: strokeAlpha.clamp(0.40, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.2 : 1.4;

      final leftAccentPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.5 : 2.5
        ..strokeCap = StrokeCap.round;

      // Paint each line rectangle individually to avoid enclosing margin whitespace
      for (int i = 0; i < absoluteRects.length; i++) {
        final rect = absoluteRects[i];
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.0));
        
        // Translucent background
        canvas.drawRRect(rrect, fillPaint);
        
        // Subtle outline / underline (Section 65)
        canvas.drawRRect(rrect, strokePaint);

        // First line gets a distinctive left border indicator
        if (i == 0) {
          canvas.drawLine(
            Offset(rect.left, rect.top),
            Offset(rect.left, rect.bottom),
            leftAccentPaint,
          );
        }
      }

      // Draw subtle category / severity pill on first rectangle
      if (isSelected || finding.severity == LegalRiskSeverity.high) {
        final firstRect = absoluteRects.first;
        final badgePaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        const badgeWidth = 64.0;
        const badgeHeight = 15.0;
        final badgeTop = (firstRect.top - badgeHeight - 2).clamp(0.0, size.height - badgeHeight);
        final badgeRect = Rect.fromLTWH(firstRect.left, badgeTop, badgeWidth, badgeHeight);
        
        canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), badgePaint);

        final textSpan = TextSpan(
          text: finding.severity == LegalRiskSeverity.high ? 'HIGH RISK' : 'FLAGGED',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            badgeRect.left + (badgeWidth - textPainter.width) / 2,
            badgeRect.top + (badgeHeight - textPainter.height) / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DocumentHighlightPainter oldDelegate) {
    return oldDelegate.findings != findings ||
        oldDelegate.selectedFindingId != selectedFindingId ||
        oldDelegate.pageIndex != pageIndex ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.severityFilter != severityFilter;
  }
}
