import 'package:flutter/material.dart';

/// Animated scanner overlay with corner brackets and a pulsing laser line.
/// Drop this on top of a MobileScanner widget.
class ScannerOverlay extends StatefulWidget {
  final Color borderColor;
  final Color laserColor;
  final double borderWidth;
  final double cornerSize;
  final double frameSize;

  const ScannerOverlay({
    super.key,
    this.borderColor = const Color(0xFF00E3FD),
    this.laserColor = const Color(0xFF00E3FD),
    this.borderWidth = 3.5,
    this.cornerSize = 28,
    this.frameSize = 240,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _laserAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _laserAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark overlay with transparent centre cutout
        CustomPaint(
          size: Size.infinite,
          painter: _OverlayPainter(frameSize: widget.frameSize),
        ),
        // Corner brackets + animated laser
        Center(
          child: SizedBox(
            width: widget.frameSize,
            height: widget.frameSize,
            child: Stack(
              children: [
                // Four corner brackets
                _Corner(
                  alignment: Alignment.topLeft,
                  borderColor: widget.borderColor,
                  borderWidth: widget.borderWidth,
                  size: widget.cornerSize,
                  topLeft: true,
                ),
                _Corner(
                  alignment: Alignment.topRight,
                  borderColor: widget.borderColor,
                  borderWidth: widget.borderWidth,
                  size: widget.cornerSize,
                  topRight: true,
                ),
                _Corner(
                  alignment: Alignment.bottomLeft,
                  borderColor: widget.borderColor,
                  borderWidth: widget.borderWidth,
                  size: widget.cornerSize,
                  bottomLeft: true,
                ),
                _Corner(
                  alignment: Alignment.bottomRight,
                  borderColor: widget.borderColor,
                  borderWidth: widget.borderWidth,
                  size: widget.cornerSize,
                  bottomRight: true,
                ),
                // Animated laser line
                AnimatedBuilder(
                  animation: _laserAnim,
                  builder: (_, _) {
                    final top = _laserAnim.value * (widget.frameSize - 2);
                    return Positioned(
                      top: top,
                      left: 12,
                      right: 12,
                      child: Container(
                        height: 2.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.laserColor.withValues(alpha: 0.0),
                              widget.laserColor.withValues(alpha: 0.9),
                              widget.laserColor.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a translucent dark overlay with a transparent rectangle in the centre.
class _OverlayPainter extends CustomPainter {
  final double frameSize;
  _OverlayPainter({required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.60);

    final centreX = size.width / 2;
    final centreY = size.height / 2;
    final half = frameSize / 2;

    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(centreX - half, centreY - half, centreX + half, centreY + half),
          const Radius.circular(12),
        ),
      );

    canvas.drawPath(
      Path.combine(PathOperation.difference, outerPath, holePath),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => old.frameSize != frameSize;
}

/// A single corner bracket drawn with a BorderRadius.
class _Corner extends StatelessWidget {
  final Alignment alignment;
  final Color borderColor;
  final double borderWidth;
  final double size;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _Corner({
    required this.alignment,
    required this.borderColor,
    required this.borderWidth,
    required this.size,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: borderColor, width: borderWidth);
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: (topLeft || topRight) ? border : BorderSide.none,
            bottom: (bottomLeft || bottomRight) ? border : BorderSide.none,
            left: (topLeft || bottomLeft) ? border : BorderSide.none,
            right: (topRight || bottomRight) ? border : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: topLeft ? const Radius.circular(8) : Radius.zero,
            topRight: topRight ? const Radius.circular(8) : Radius.zero,
            bottomLeft: bottomLeft ? const Radius.circular(8) : Radius.zero,
            bottomRight: bottomRight ? const Radius.circular(8) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
