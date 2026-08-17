import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/scan_result_model.dart';
import '../../services/scan_history_service.dart';
import '../../utils/permissions.dart';
import '../../widgets/scanner_overlay.dart';
import '../../widgets/scan_result_dialog.dart';

/// Real-time QR + Barcode scanner screen powered by mobile_scanner.
///
/// Features:
/// - Live camera scanning with animated overlay
/// - Flash toggle and camera flip
/// - Gallery image scanning
/// - Immediate result bottom sheet on detection
/// - Saves to scan history
class QrScannerScreen extends StatefulWidget {
  final ScanHistoryService historyService;

  const QrScannerScreen({Key? key, required this.historyService})
      : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  bool _isProcessing = false; // debounce rapid detections
  bool _hasPermission = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.itf14,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.pdf417,
        BarcodeFormat.aztec,
      ],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final granted = await PermissionsUtil.requestCamera(context);
    setState(() {
      _hasPermission = granted;
      _checkingPermission = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _controller.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _isProcessing = true;
    HapticFeedback.mediumImpact();
    _controller.stop();

    final result = BarcodeResult(
      rawValue: rawValue,
      format: _formatName(barcode.format),
      displayType: _displayType(rawValue, barcode.type),
      timestamp: DateTime.now(),
    );

    _showResultSheet(result);
  }

  void _showResultSheet(BarcodeResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanResultDialog(
        result: result,
        onSaveToHistory: () async {
          await widget.historyService.addBarcode(result);
        },
      ),
    ).whenComplete(() {
      // Resume scanner after sheet dismissed
      if (mounted) {
        _isProcessing = false;
        _controller.start();
      }
    });
  }

  /// Scan a barcode/QR from a gallery image
  Future<void> _scanFromGallery() async {
    final granted = await PermissionsUtil.requestStorage(context);
    if (!granted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (!mounted) return;
    setState(() => _isProcessing = true);
    _controller.stop();

    try {
      final result = await _controller.analyzeImage(image.path);
      if (result == null || result.barcodes.isEmpty) {
        if (mounted) {
          _showNoCodeFoundSnackBar();
        }
        return;
      }
      final barcode = result.barcodes.first;
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) {
        if (mounted) _showNoCodeFoundSnackBar();
        return;
      }
      if (!mounted) return;
      final barcodeResult = BarcodeResult(
        rawValue: rawValue,
        format: _formatName(barcode.format),
        displayType: _displayType(rawValue, barcode.type),
        timestamp: DateTime.now(),
        imagePath: image.path,
      );
      _showResultSheet(barcodeResult);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _isProcessing = false;
        _controller.start();
      }
    }
  }

  void _showNoCodeFoundSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No QR code or barcode found in this image'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _isProcessing = false;
    _controller.start();
  }

  String _formatName(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.code128:
        return 'CODE-128';
      case BarcodeFormat.code39:
        return 'CODE-39';
      case BarcodeFormat.code93:
        return 'CODE-93';
      case BarcodeFormat.itf14:
        return 'ITF-14';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.aztec:
        return 'Aztec';
      default:
        return 'Barcode';
    }
  }

  String _displayType(String rawValue, BarcodeType? type) {
    if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
      return 'URL';
    }
    if (rawValue.startsWith('tel:')) return 'Phone';
    if (rawValue.startsWith('mailto:')) return 'Email';
    if (rawValue.startsWith('WIFI:')) return 'Wi-Fi';
    if (rawValue.startsWith('BEGIN:VCARD')) return 'Contact';
    if (rawValue.startsWith('geo:')) return 'Location';
    switch (type) {
      case BarcodeType.url:
        return 'URL';
      case BarcodeType.phone:
        return 'Phone';
      case BarcodeType.email:
        return 'Email';
      case BarcodeType.contactInfo:
        return 'Contact';
      case BarcodeType.wifi:
        return 'Wi-Fi';
      case BarcodeType.product:
        return 'Product';
      default:
        return 'Text';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _checkingPermission
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? _buildPermissionDenied(theme)
              : Stack(
                  children: [
                    // Camera view
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onBarcodeDetected,
                      errorBuilder: (ctx, error) {
                        return Center(
                          child: Text(
                            'Camera error: ${error.errorCode.name}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),

                    // Scanner overlay with animated laser
                    const ScannerOverlay(),

                    // Top bar
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            _CircleBtn(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            _CircleBtn(
                              icon: _isFlashOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              onTap: () {
                                _controller.toggleTorch();
                                setState(() => _isFlashOn = !_isFlashOn);
                              },
                              isActive: _isFlashOn,
                            ),
                            const SizedBox(width: 10),
                            _CircleBtn(
                              icon: Icons.flip_camera_ios_rounded,
                              onTap: () {
                                _controller.switchCamera();
                                setState(
                                    () => _isFrontCamera = !_isFrontCamera);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Title + hint
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.15,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            'QR & Barcode Scanner',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Point camera at any QR code or barcode',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom bar — gallery + history
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _BottomAction(
                                icon: Icons.photo_library_outlined,
                                label: 'Gallery',
                                onTap: _scanFromGallery,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPermissionDenied(ThemeData theme) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Camera access required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Please enable camera permission in Settings to scan QR codes and barcodes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checkCameraPermission,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00E3FD).withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? const Color(0xFF00E3FD)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon,
            color: isActive ? const Color(0xFF00E3FD) : Colors.white,
            size: 20),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
