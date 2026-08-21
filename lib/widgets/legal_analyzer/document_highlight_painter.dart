import 'package:flutter/material.dart';
import '../../core/legal/models/legal_finding.dart';

class DocumentHighlightPainter extends CustomPainter {
  final List<LegalFinding> findings;
  final String? selectedFindingId;
  final int pageIndex;

  DocumentHighlightPainter({
    required this.findings,
    this.selectedFindingId,
    required this.pageIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final finding in findings) {
      if (finding.pageIndex != pageIndex || finding.boundingBox == null) continue;

      final rect = finding.boundingBox!.toAbsoluteRect(size);
      final isSelected = finding.id == selectedFindingId;
      final baseColor = finding.severity.color;

      // Draw glowing background
      final fillPaint = Paint()
        ..color = baseColor.withValues(alpha: isSelected ? 0.35 : 0.20)
        ..style = PaintingStyle.fill;

      // Draw border
      final strokePaint = Paint()
        ..color = baseColor.withValues(alpha: isSelected ? 1.0 : 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.0 : 1.8;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, strokePaint);

      // Draw pill badge tag
      if (isSelected || finding.severity == LegalRiskSeverity.high) {
        final badgePaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        final badgeRect = Rect.fromLTWH(rect.left, rect.top - 16, 60, 14);
        canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), badgePaint);

        final textSpan = TextSpan(
          text: finding.severity.displayName.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 15));
      }
    }
  }

  @override
  bool shouldRepaint(covariant DocumentHighlightPainter oldDelegate) {
    return oldDelegate.findings != findings ||
        oldDelegate.selectedFindingId != selectedFindingId ||
        oldDelegate.pageIndex != pageIndex;
  }
}
