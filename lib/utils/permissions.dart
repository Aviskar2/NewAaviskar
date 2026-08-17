import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Utility for requesting and handling runtime permissions.
class PermissionsUtil {
  /// Request camera permission.
  /// Returns true if granted (including previously permanently granted).
  static Future<bool> requestCamera(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied && context.mounted) {
      await _showSettingsDialog(
        context,
        title: 'Camera Permission Required',
        message:
            'NyayaSathi needs camera access to scan QR codes, barcodes, and capture images for OCR. '
            'Please enable it in app settings.',
      );
    }
    return false;
  }

  /// Request storage / media permission for reading gallery images.
  static Future<bool> requestStorage(BuildContext context) async {
    // Android 13+ uses READ_MEDIA_IMAGES; older uses READ_EXTERNAL_STORAGE
    final status = await Permission.photos.request();
    if (status.isGranted) return true;

    // Fallback for older Android
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return true;

    if ((status.isPermanentlyDenied || storageStatus.isPermanentlyDenied) &&
        context.mounted) {
      await _showSettingsDialog(
        context,
        title: 'Storage Permission Required',
        message:
            'NyayaSathi needs access to your photos and files to process images for OCR and barcode scanning. '
            'Please enable it in app settings.',
      );
    }
    return false;
  }

  /// Check camera permission status without requesting.
  static Future<bool> isCameraGranted() async {
    return Permission.camera.isGranted;
  }

  /// Shows a dialog directing the user to app settings when permanently denied.
  static Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not Now',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
