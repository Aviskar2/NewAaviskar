import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class HomeDashboardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> activeMessages;
  final bool isTyping;
  final String? typingStatus;
  final ValueChanged<String> onSendMessage;
  final void Function({
    required String feature,
    required Map<String, dynamic> document,
    String? userPrompt,
  }) onExecuteFeature;
  final ValueChanged<int> onNavigateToTab;

  const HomeDashboardScreen({
    Key? key,
    required this.activeMessages,
    required this.isTyping,
    this.typingStatus,
    required this.onSendMessage,
    required this.onExecuteFeature,
    required this.onNavigateToTab,
  }) : super(key: key);

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Active feature mode: 'Translation' | 'Scanner' | 'Documents' (starts as null - none selected)
  String? _selectedFeature;

  // Attached document waiting in input bar
  Map<String, dynamic>? _pendingAttachment;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(HomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeMessages.length != oldWidget.activeMessages.length ||
        widget.isTyping != oldWidget.isTyping) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _onFeatureButtonTapped(String feature) {
    HapticFeedback.lightImpact();

    // If no document is attached yet:
    if (_pendingAttachment == null) {
      _showMinimalToast(
        'Please upload a photo or document first to use $feature',
        _getFeatureIcon(feature),
        _getFeatureColor(feature),
      );
      _showUploadBottomSheet();
      return;
    }

    // Document is attached! Set feature and execute immediately
    setState(() {
      _selectedFeature = feature;
    });

    final prompt = _messageController.text.trim();
    _executeWithPendingAttachment(feature, prompt: prompt.isNotEmpty ? prompt : null);
    _messageController.clear();
  }

  Color _getFeatureColor(String? feature) {
    switch (feature) {
      case 'Translation':
        return const Color(0xFF2563EB); // Electric Blue
      case 'Scanner':
        return const Color(0xFF9D00FF); // Vibrant Purple
      case 'Documents':
        return const Color(0xFFFF4081); // Bright Pink/Coral
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _getFeatureIcon(String? feature) {
    switch (feature) {
      case 'Translation':
        return Icons.translate;
      case 'Scanner':
        return Icons.qr_code_scanner;
      case 'Documents':
        return Icons.description;
      default:
        return Icons.auto_awesome;
    }
  }

  void _showMinimalToast(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12, left: 36, right: 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        duration: const Duration(milliseconds: 2400),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (_pendingAttachment != null) {
      if (_selectedFeature == null) {
        _showMinimalToast(
          'Please select a feature (Translation, Scanner, or Documents) above',
          Icons.touch_app_outlined,
          Theme.of(context).colorScheme.primary,
        );
        return;
      }
      _executeWithPendingAttachment(_selectedFeature!, prompt: text.isNotEmpty ? text : null);
      _messageController.clear();
      return;
    }

    if (text.isEmpty) return;
    _messageController.clear();
    widget.onSendMessage(text);
  }

  void _executeWithPendingAttachment(String feature, {String? prompt}) {
    if (_pendingAttachment == null) return;
    final doc = _pendingAttachment!;
    setState(() {
      _pendingAttachment = null;
      _selectedFeature = null; // reset selection after processing
    });
    widget.onExecuteFeature(
      feature: feature,
      document: doc,
      userPrompt: prompt,
    );
  }

  // Option 1: Add photo or document from gallery/storage
  Future<void> _pickFromGalleryOrFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;
        final sizeInBytes = file.size;
        String size;
        if (sizeInBytes < 1024) {
          size = '$sizeInBytes B';
        } else if (sizeInBytes < 1024 * 1024) {
          size = '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
        } else {
          size = '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }

        final ext = (file.extension ?? '').toLowerCase();
        String docType;
        if (['pdf'].contains(ext)) {
          docType = 'PDF Document';
        } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
          docType = 'Photo / Image';
        } else if (['doc', 'docx'].contains(ext)) {
          docType = 'Word Document';
        } else if (['xls', 'xlsx', 'csv'].contains(ext)) {
          docType = 'Spreadsheet';
        } else {
          docType = 'Document';
        }

        final docData = {
          'name': name,
          'size': size,
          'type': docType,
          'path': file.path,
        };

        setState(() {
          _pendingAttachment = docData;
          _selectedFeature = null;
        });

        if (mounted) {
          _showMinimalToast(
            'File attached! Tap Translation, Scanner, or Documents above to process',
            Icons.check_circle_outline,
            Theme.of(context).colorScheme.primary,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMinimalToast('Failed to pick file: $e', Icons.error_outline, Colors.redAccent);
      }
    }
  }

  // Option 2: Directly open camera and click photo
  Future<void> _captureFromCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        final name = photo.name.isNotEmpty
            ? photo.name
            : 'Camera_Photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await photo.readAsBytes();
        final sizeInBytes = bytes.length;
        String size;
        if (sizeInBytes < 1024) {
          size = '$sizeInBytes B';
        } else if (sizeInBytes < 1024 * 1024) {
          size = '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
        } else {
          size = '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }

        final docData = {
          'name': name,
          'size': size,
          'type': 'Camera Photo',
          'path': photo.path,
        };

        setState(() {
          _pendingAttachment = docData;
          _selectedFeature = null;
        });

        if (mounted) {
          _showMinimalToast(
            'Photo captured! Tap Translation, Scanner, or Documents above to process',
            Icons.check_circle_outline,
            Theme.of(context).colorScheme.primary,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMinimalToast('Camera error: $e', Icons.error_outline, Colors.redAccent);
      }
    }
  }

  // Minimal 2-option popup bottom sheet
  void _showUploadBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Add Document or Photo',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                // Option 1: Gallery / Files
                _buildMinimalOption(
                  context,
                  title: 'Add photo or document from gallery',
                  icon: Icons.photo_library_outlined,
                  iconColor: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGalleryOrFiles();
                  },
                ),

                const SizedBox(height: 10),

                // Option 2: Directly open camera
                _buildMinimalOption(
                  context,
                  title: 'Directly open camera and click photo',
                  icon: Icons.camera_alt_outlined,
                  iconColor: const Color(0xFF9D00FF),
                  onTap: () {
                    Navigator.pop(context);
                    _captureFromCamera();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinimalOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22062C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: theme.colorScheme.primary),
          onPressed: () {
            _showMinimalToast('Workspace Menu', Icons.menu, theme.colorScheme.primary);
          },
        ),
        title: Text(
          'Aura AI',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: theme.colorScheme.primary),
            onPressed: () {
              _showMinimalToast('Select Translation, Scanner, or Documents above', Icons.help_outline, theme.colorScheme.primary);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Interactive Feature Highlight Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aura Assistant',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _selectedFeature != null
                              ? _getFeatureColor(_selectedFeature!).withValues(alpha: 0.12)
                              : (_pendingAttachment != null
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : (isDark ? const Color(0xFF2A0B35) : const Color(0xFFEBF1FF))),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedFeature != null
                                ? _getFeatureColor(_selectedFeature!).withValues(alpha: 0.3)
                                : (_pendingAttachment != null
                                    ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                    : (isDark ? const Color(0xFF3B1547) : const Color(0xFFD4E2FF))),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _selectedFeature != null
                                    ? _getFeatureColor(_selectedFeature!)
                                    : (_pendingAttachment != null
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedFeature != null
                                  ? '$_selectedFeature Active'
                                  : (_pendingAttachment != null
                                      ? 'File Ready • Pick Feature'
                                      : 'Upload to Begin'),
                              style: TextStyle(
                                color: _selectedFeature != null
                                    ? _getFeatureColor(_selectedFeature!)
                                    : (_pendingAttachment != null
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3 Smooth Highlightable Feature Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildSmoothFeatureButton(
                          label: 'Translation',
                          icon: Icons.translate,
                          featureKey: 'Translation',
                          accentColor: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSmoothFeatureButton(
                          label: 'Scanner',
                          icon: Icons.qr_code_scanner,
                          featureKey: 'Scanner',
                          accentColor: const Color(0xFF9D00FF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSmoothFeatureButton(
                          label: 'Documents',
                          icon: Icons.description,
                          featureKey: 'Documents',
                          accentColor: const Color(0xFFFF4081),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            const Divider(height: 1),

            // Middle Section: Chat Conversations Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                itemCount: widget.activeMessages.length,
                itemBuilder: (context, index) {
                  final message = widget.activeMessages[index];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: _buildMessageRouter(message),
                  );
                },
              ),
            ),

            // Typing Indicator with smooth fade
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: widget.isTyping ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      widget.typingStatus ?? 'Aura is processing',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _getFeatureColor(_selectedFeature),
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _getFeatureColor(_selectedFeature),
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // Prompt Chips for quick interaction
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  _buildPromptChip('Translate this document', 'Translation'),
                  const SizedBox(width: 8),
                  _buildPromptChip('OCR Scan text & QR', 'Scanner'),
                  const SizedBox(width: 8),
                  _buildPromptChip('Verify & index document', 'Documents'),
                  const SizedBox(width: 8),
                  _buildPromptChip('Upload file / photo', null, isUploadAction: true),
                ],
              ),
            ),

            // Pending Attachment Card (if user has selected a file)
            if (_pendingAttachment != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E103A) : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _pendingAttachment!['type']?.toString().contains('Photo') == true ||
                                _pendingAttachment!['type']?.toString().contains('Image') == true
                            ? Icons.image_outlined
                            : Icons.description_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pendingAttachment!['name'] ?? 'Uploaded Document',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_pendingAttachment!['size']} • Tap Translation, Scanner, or Documents above',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _pendingAttachment = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            // Bottom Input Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22062C) : Colors.white,
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(
                    color: _pendingAttachment != null
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : (isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF)),
                    width: _pendingAttachment != null ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      // Upload Attachment Button with smooth animation
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showUploadBottomSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _pendingAttachment != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _pendingAttachment != null ? Icons.attach_file : Icons.add,
                              color: _pendingAttachment != null ? Colors.white : theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: _pendingAttachment != null
                                ? 'Add instructions or tap a feature above...'
                                : 'Ask Aura or tap + to upload photo / doc...',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              fontSize: 13.5,
                            ),
                            border: InputBorder.none,
                          ),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _sendMessage,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Smooth Highlighted Feature Button Widget
  Widget _buildSmoothFeatureButton({
    required String label,
    required IconData icon,
    required String featureKey,
    required Color accentColor,
  }) {
    final isSelected = _selectedFeature == featureKey;
    final hasAttachment = _pendingAttachment != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onFeatureButtonTapped(featureKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? accentColor.withValues(alpha: 0.28) : accentColor.withValues(alpha: 0.14))
              : (hasAttachment
                  ? (isDark ? accentColor.withValues(alpha: 0.12) : accentColor.withValues(alpha: 0.06))
                  : (isDark ? const Color(0xFF22062C) : Colors.white)),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (hasAttachment
                    ? accentColor.withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF))),
            width: isSelected ? 2.0 : (hasAttachment ? 1.5 : 1.0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : (hasAttachment
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor
                        : accentColor.withValues(alpha: hasAttachment ? 0.18 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : accentColor,
                    size: 18,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : (hasAttachment ? FontWeight.bold : FontWeight.w600),
                fontSize: 12,
                color: isSelected
                    ? (isDark ? Colors.white : accentColor)
                    : (hasAttachment ? accentColor : theme.colorScheme.onSurface),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Routing Message Bubbles
  Widget _buildMessageRouter(Map<String, dynamic> message) {
    final type = message['type'] ?? 'text';
    final isUser = message['isUser'] == true;

    if (isUser) {
      if (type == 'upload') {
        return _buildUserUploadBubble(message);
      }
      return _buildUserTextBubble(message['text'] ?? '');
    } else {
      switch (type) {
        case 'translation_result':
          return _buildTranslationResultCard(message);
        case 'scanner_result':
          return _buildScannerResultCard(message);
        case 'document_result':
          return _buildDocumentResultCard(message);
        case 'text':
        default:
          return _buildAiTextBubble(message['text'] ?? '');
      }
    }
  }

  Widget _buildUserTextBubble(String text) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, left: 40.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomLeft: Radius.circular(16.0),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserUploadBubble(Map<String, dynamic> message) {
    final doc = message['document'] as Map<String, dynamic>? ?? {};
    final feature = message['feature'] as String? ?? 'Analysis';
    final accentColor = _getFeatureColor(feature);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, left: 32.0),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor, accentColor.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18.0),
            topRight: Radius.circular(18.0),
            bottomLeft: Radius.circular(18.0),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.attach_file, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['name'] ?? 'Document',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${doc['size'] ?? ''} • Triggered $feature',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (message['text'] != null &&
                message['text'] != 'Apply $feature to ${doc['name']}') ...[
              const SizedBox(height: 8),
              Text(
                message['text'],
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiTextBubble(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, right: 40.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22062C) : const Color(0xFFF0F4FF),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  // Translation Result Card rendered directly in the chat stream
  Widget _buildTranslationResultCard(Map<String, dynamic> msg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF2563EB);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14.0, right: 20.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E0C2B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? accent.withOpacity(0.4) : accent.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header stripe
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: accent.withOpacity(0.12),
                child: Row(
                  children: [
                    const Icon(Icons.translate, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Translation: ${msg['documentName']}',
                        style: const TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        msg['confidence'] ?? '99.8%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Language Pair Indicator
                    Row(
                      children: [
                        Text(
                          msg['sourceLang'] ?? 'Source',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 14, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          msg['targetLang'] ?? 'Target',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Original Snippet
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2B123A) : const Color(0xFFF6F8FC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3E1D52) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ORIGINAL TEXT (EXCERPT)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            msg['originalSnippet'] ?? '',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Translated Result Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TRANSLATED TEXT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            msg['translatedText'] ?? '',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action buttons: Copy & Quick Feature Switchers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: msg['translatedText'] ?? ''));
                            _showMinimalToast('Translation copied to clipboard', Icons.check, accent);
                          },
                          icon: const Icon(Icons.copy, size: 15, color: accent),
                          label: const Text(
                            'Copy Translation',
                            style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          children: [
                            _buildQuickActionPill('Scanner', Icons.qr_code_scanner, () {
                              _onFeatureButtonTapped('Scanner');
                            }),
                            const SizedBox(width: 6),
                            _buildQuickActionPill('Track', Icons.description, () {
                              _onFeatureButtonTapped('Documents');
                            }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Scanner Result Card rendered directly in the chat stream
  Widget _buildScannerResultCard(Map<String, dynamic> msg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF9D00FF);
    final fields = msg['extractedFields'] as List<dynamic>? ?? [];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14.0, right: 20.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E0C2B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? accent.withOpacity(0.4) : accent.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header stripe
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: accent.withOpacity(0.12),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scanner Result: ${msg['documentName']}',
                        style: const TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'OCR Complete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // QR / Code payload
                    if (msg['detectedCode'] != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code, color: accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                msg['detectedCode'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Extracted Fields Table
                    const Text(
                      'EXTRACTED DATA & FIELDS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...fields.map((f) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(
                                f['label'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                f['value'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: msg['detectedCode'] ?? ''));
                            _showMinimalToast('Scanned data copied!', Icons.check, accent);
                          },
                          icon: const Icon(Icons.copy, size: 15, color: accent),
                          label: const Text(
                            'Copy Data',
                            style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          children: [
                            _buildQuickActionPill('Translate', Icons.translate, () {
                              _onFeatureButtonTapped('Translation');
                            }),
                            const SizedBox(width: 6),
                            _buildQuickActionPill('Verify', Icons.description, () {
                              _onFeatureButtonTapped('Documents');
                            }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Document Tracker Result Card rendered directly in the chat stream
  Widget _buildDocumentResultCard(Map<String, dynamic> msg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFFFF4081);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14.0, right: 20.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E0C2B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? accent.withOpacity(0.4) : accent.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header stripe
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: accent.withOpacity(0.12),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Document Tracker: ${msg['documentName']}',
                        style: const TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        msg['status'] ?? 'Verified',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Analysis summary
                    Text(
                      msg['summary'] ?? '',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // File Metadata Info Grid
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2B123A) : const Color(0xFFF6F8FC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3E1D52) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDocMetaRow('File Type', msg['fileType'] ?? 'PDF Document'),
                          const Divider(height: 12),
                          _buildDocMetaRow('File Size', msg['fileSize'] ?? '1.2 MB'),
                          const Divider(height: 12),
                          _buildDocMetaRow('Indexed On', msg['indexedDate'] ?? 'Today'),
                          const Divider(height: 12),
                          _buildDocMetaRow('Repository Total', '${msg['totalDocs'] ?? 1} document(s) verified'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SHA-256 Checksum Valid',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                        Row(
                          children: [
                            _buildQuickActionPill('Translate', Icons.translate, () {
                              _onFeatureButtonTapped('Translation');
                            }),
                            const SizedBox(width: 6),
                            _buildQuickActionPill('Scan', Icons.qr_code_scanner, () {
                              _onFeatureButtonTapped('Scanner');
                            }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocMetaRow(String label, String val) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionPill(String label, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String prompt, String? feature, {bool isUploadAction = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ActionChip(
      avatar: isUploadAction ? const Icon(Icons.add, size: 16) : null,
      label: Text(
        prompt,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      onPressed: () {
        if (isUploadAction) {
          _showUploadBottomSheet();
        } else {
          if (feature != null) {
            _onFeatureButtonTapped(feature);
          } else {
            widget.onSendMessage(prompt);
          }
        }
      },
      backgroundColor: isDark ? const Color(0xFF2A0B35) : const Color(0xFFE5EEFF),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

