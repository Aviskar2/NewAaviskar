import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scan_result_model.dart';

/// Comprehensive utility for launching URLs, phone numbers, emails, maps,
/// and web searches from scan results.
class UrlLauncherUtil {
  /// Simple URL launcher without requiring BuildContext
  static Future<bool> launch(String rawUrl) async {
    String url = rawUrl.trim();
    if (url.isEmpty) return false;
    if (!url.startsWith(RegExp(r'^[a-zA-Z0-9+.-]+://'))) {
      url = 'https://$url';
    }
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Open a URL safely with multiple fallback strategies.
  static Future<bool> openUrl(BuildContext context, String rawUrl) async {
    String url = rawUrl.trim();
    if (url.isEmpty) return false;

    // Normalize URL if missing scheme
    if (!url.startsWith(RegExp(r'^[a-zA-Z0-9+.-]+://'))) {
      if (url.startsWith('www.')) {
        url = 'https://$url';
      } else if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      }
    }

    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      uri = null;
    }

    if (uri == null) {
      _showErrorSnackBar(context, 'Invalid URL: $rawUrl');
      return false;
    }

    HapticFeedback.lightImpact();

    try {
      // 1. Try launching in external application (e.g. Chrome / default browser)
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;

      // 2. Fallback to platform default
      final fallbackLaunched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (fallbackLaunched) return true;

      // 3. Fallback to in-app web view
      final inAppLaunched = await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
      );
      if (inAppLaunched) return true;
    } catch (e) {
      debugPrint('UrlLauncher error: $e');
    }

    // If all launch attempts failed, copy to clipboard and notify
    if (context.mounted) {
      Clipboard.setData(ClipboardData(text: url));
      _showErrorSnackBar(
        context,
        'Could not open URL directly. Link copied to clipboard.',
      );
    }
    return false;
  }

  /// Search text on Google
  static Future<bool> searchWeb(BuildContext context, String query) async {
    final searchUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(query.trim())}';
    return openUrl(context, searchUrl);
  }

  /// Handle any BarcodeResult appropriately based on its content
  static Future<void> handleBarcodeAction(
    BuildContext context,
    BarcodeResult result,
  ) async {
    final val = result.rawValue.trim();
    if (val.isEmpty) return;

    if (result.isUrl || val.startsWith('http://') || val.startsWith('https://')) {
      await openUrl(context, val);
    } else if (val.startsWith('tel:')) {
      await _launchScheme(context, val, 'Could not launch dialer');
    } else if (val.startsWith('mailto:')) {
      await _launchScheme(context, val, 'Could not open mail app');
    } else if (val.startsWith('sms:')) {
      await _launchScheme(context, val, 'Could not open SMS app');
    } else if (val.startsWith('geo:')) {
      await _launchScheme(context, val, 'Could not open Maps');
    } else if (val.startsWith('upi://')) {
      await _launchScheme(context, val, 'No UPI payment app found');
    } else {
      // For general barcodes / text, perform web search
      await searchWeb(context, val);
    }
  }

  static Future<bool> _launchScheme(
    BuildContext context,
    String uriString,
    String failureMessage,
  ) async {
    try {
      final uri = Uri.parse(uriString);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (e) {
      debugPrint('Scheme launch error: $e');
    }
    if (context.mounted) {
      _showErrorSnackBar(context, failureMessage);
    }
    return false;
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red.shade800,
      ),
    );
  }
}
