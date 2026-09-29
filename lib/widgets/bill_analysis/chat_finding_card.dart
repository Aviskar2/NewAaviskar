/// Compact finding card for chat-stream display.
/// Shows a single finding with expand/collapse in a minimal layout.
library;

import 'package:flutter/material.dart';
import '../../models/analysis_result.dart';

class ChatFindingCard extends StatefulWidget {
  final AnalysisFinding finding;
  final bool compact;

  const ChatFindingCard({
    super.key,
    required this.finding,
    this.compact = false,
  });

  @override
  State<ChatFindingCard> createState() => _ChatFindingCardState();
}

class _ChatFindingCardState extends State<ChatFindingCard> {
  bool _expanded = false;

  Color _color() {
    switch (widget.finding.severity) {
      case FindingSeverity.ok:
        return const Color(0xFF16A34A);
      case FindingSeverity.verify:
        return const Color(0xFFD97706);
      case FindingSeverity.suspicious:
        return const Color(0xFFDC2626);
      case FindingSeverity.error:
        return const Color(0xFFB91C1C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color();
    final f = widget.finding;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(widget.compact ? 8 : 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.severity.emoji, style: TextStyle(fontSize: widget.compact ? 12 : 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    f.title,
                    style: TextStyle(
                      fontSize: widget.compact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                if (!widget.compact)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                  ),
              ],
            ),
            if (!widget.compact && f.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                f.explanation,
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
            if (_expanded) ...[
              if (f.whatFound != null) _detail('Found', f.whatFound!, theme),
              if (f.whatExpected != null) _detail('Expected', f.whatExpected!, theme),
              if (f.difference != null)
                _detail('Difference', '₹${f.difference!.toStringAsFixed(2)}', theme),
              if (f.recommendation != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Text('💡 ', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Text(
                          f.recommendation!,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onPrimaryContainer,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
