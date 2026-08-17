import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_result_model.dart';
import '../utils/url_launcher_util.dart';

/// Bottom sheet shown immediately after a QR/barcode is detected.
/// Provides working Copy, Open / Search URL, and Save to History actions.
class ScanResultDialog extends StatelessWidget {
  final BarcodeResult result;
  final VoidCallback onSaveToHistory;
  final VoidCallback? onOpenUrl;

  const ScanResultDialog({
    Key? key,
    required this.result,
    required this.onSaveToHistory,
    this.onOpenUrl,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required BarcodeResult result,
    required VoidCallback onSaveToHistory,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanResultDialog(
        result: result,
        onSaveToHistory: onSaveToHistory,
        onOpenUrl: () {
          UrlLauncherUtil.handleBarcodeAction(context, result);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1B0424) : Colors.white;

    final wifiData = result.isWifi ? _parseWifi(result.rawValue) : null;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? const Color(0xFF32113D)
                : const Color(0xFFE5EEFF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format badge + title
                  Row(
                    children: [
                      _FormatBadge(format: result.format, theme: theme),
                      const SizedBox(width: 10),
                      Text(
                        result.displayType,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Wi-Fi details card or Raw value card
                  if (wifiData != null) ...[
                    _WifiCard(wifiData: wifiData, isDark: isDark, theme: theme),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A0B35)
                            : const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF32113D)
                              : const Color(0xFFDDE7FF),
                        ),
                      ),
                      child: SelectableText(
                        result.rawValue,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),
                  Text(
                    _formatTimestamp(result.timestamp),
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 18),

                  // Action buttons
                  Row(
                    children: [
                      _ActionBtn(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: result.rawValue));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        theme: theme,
                      ),
                      const SizedBox(width: 10),
                      _ActionBtn(
                        icon: _getActionIcon(),
                        label: _getActionLabel(),
                        onTap: () {
                          Navigator.pop(context);
                          if (onOpenUrl != null) {
                            onOpenUrl!.call();
                          } else {
                            UrlLauncherUtil.handleBarcodeAction(context, result);
                          }
                        },
                        theme: theme,
                        isPrimary: true,
                      ),
                      const SizedBox(width: 10),
                      _ActionBtn(
                        icon: Icons.bookmark_add_outlined,
                        label: 'Save',
                        onTap: () {
                          onSaveToHistory();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved to history'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        theme: theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon() {
    if (result.isUrl) return Icons.open_in_browser_rounded;
    if (result.isPhone) return Icons.phone_forwarded_rounded;
    if (result.isEmail) return Icons.email_outlined;
    if (result.isUpi) return Icons.payment_rounded;
    if (result.isWifi) return Icons.wifi_rounded;
    return Icons.search_rounded;
  }

  String _getActionLabel() {
    if (result.isUrl) return 'Open';
    if (result.isPhone) return 'Call';
    if (result.isEmail) return 'Email';
    if (result.isUpi) return 'Pay';
    if (result.isWifi) return 'Connect';
    return 'Search';
  }

  Map<String, String> _parseWifi(String raw) {
    // Format: WIFI:S:SSID;T:WPA;P:Password;H:false;;
    final Map<String, String> data = {};
    final parts = raw.replaceFirst('WIFI:', '').split(';');
    for (final part in parts) {
      if (part.startsWith('S:')) data['ssid'] = part.substring(2);
      if (part.startsWith('T:')) data['type'] = part.substring(2);
      if (part.startsWith('P:')) data['password'] = part.substring(2);
      if (part.startsWith('H:')) data['hidden'] = part.substring(2);
    }
    return data;
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm · ${dt.day}/${dt.month}/${dt.year}';
  }
}

class _WifiCard extends StatelessWidget {
  final Map<String, String> wifiData;
  final bool isDark;
  final ThemeData theme;

  const _WifiCard({
    required this.wifiData,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final ssid = wifiData['ssid'] ?? 'Unknown Network';
    final pass = wifiData['password'] ?? '';
    final type = wifiData['type'] ?? 'WPA/WPA2';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A0B35) : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFDDE7FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_rounded, color: Color(0xFF00BFA5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ssid,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (pass.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Password: $pass',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy password',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pass));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Wi-Fi Password copied'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String format;
  final ThemeData theme;
  const _FormatBadge({required this.format, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isQr = format.toLowerCase().contains('qr');
    final color = isQr ? const Color(0xFF9D00FF) : const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        format,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isPrimary;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Expanded(
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
