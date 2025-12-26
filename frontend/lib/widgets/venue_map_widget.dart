import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../utils/debug_logger.dart';

class VenueMapWidget extends StatefulWidget {
  final String imagePath;
  final List<Widget> overlays;
  final Function(Offset)? onTap;
  final bool interactive;
  final Function(Rect?)? onImageBoundsChanged;

  const VenueMapWidget({
    super.key,
    required this.imagePath,
    this.overlays = const [],
    this.onTap,
    this.interactive = true,
    this.onImageBoundsChanged,
  });

  @override
  State<VenueMapWidget> createState() => _VenueMapWidgetState();
  
  /// Calculate the bounds of the image within the widget
  /// Returns a Rect with (offsetX, offsetY, width, height)
  static Rect calculateImageBounds(ui.Image image, Size containerSize) {
    final imageAspectRatio = image.width / image.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    double drawWidth, drawHeight, offsetX, offsetY;

    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider - fit to width
      drawWidth = containerSize.width;
      drawHeight = containerSize.width / imageAspectRatio;
      offsetX = 0;
      offsetY = (containerSize.height - drawHeight) / 2;
    } else {
      // Image is taller - fit to height
      drawHeight = containerSize.height;
      drawWidth = containerSize.height * imageAspectRatio;
      offsetX = (containerSize.width - drawWidth) / 2;
      offsetY = 0;
    }

    return Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight);
  }
}

class _VenueMapWidgetState extends State<VenueMapWidget> {
  ui.Image? _image;
  bool _isLoading = true;
  String? _error;
  bool _isDisposed = false;
  Size? _containerSize;

  // #region agent log
  void _log(String message, Map<String, dynamic> data) {
    debugLog('venue_map_widget.dart', message, data, hypothesisId: 'D');
  }
  // #endregion

  @override
  void initState() {
    super.initState();
    // #region agent log
    _log('initState START', {'mounted': mounted, 'isDisposed': _isDisposed, 'imagePath': widget.imagePath});
    // #endregion
    _loadImage();
  }

  Future<void> _loadImage() async {
    // #region agent log
    _log('_loadImage START', {'mounted': mounted, 'isDisposed': _isDisposed, 'imagePath': widget.imagePath});
    // #endregion
    try {
      final ByteData data = await rootBundle.load(widget.imagePath);
      final Uint8List bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      // #region agent log
      _log('_loadImage COMPLETED', {'mounted': mounted, 'isDisposed': _isDisposed, 'imageLoaded': true});
      // #endregion
      if (mounted && !_isDisposed) {
        setState(() {
          _image = frame.image;
          _isLoading = false;
          _error = null;
        });
        // #region agent log
        _log('_loadImage setState CALLED', {'mounted': mounted, 'isDisposed': _isDisposed});
        // #endregion
      } else {
        // #region agent log
        _log('_loadImage setState SKIPPED', {'mounted': mounted, 'isDisposed': _isDisposed});
        // #endregion
        frame.image.dispose();
      }
    } catch (e) {
      // #region agent log
      _log('_loadImage ERROR', {'mounted': mounted, 'isDisposed': _isDisposed, 'error': e.toString()});
      // #endregion
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _error = 'Error loading image: $e';
        });
      }
    }
  }

  @override
  void didUpdateWidget(VenueMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // #region agent log
    _log('didUpdateWidget', {'mounted': mounted, 'isDisposed': _isDisposed, 'imagePathChanged': oldWidget.imagePath != widget.imagePath});
    // #endregion
    // Only reload image if imagePath actually changed (not just container size)
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
    // If image path is the same, just update bounds when container size changes
    // The image will resize smoothly via CustomPainter
  }

  @override
  void dispose() {
    // #region agent log
    _log('dispose START', {'mounted': mounted, 'isDisposed': _isDisposed, 'hasImage': _image != null});
    // #endregion
    _isDisposed = true;
    _image?.dispose();
    // #region agent log
    _log('dispose Image DISPOSED', {'mounted': mounted});
    // #endregion
    super.dispose();
    // #region agent log
    _log('dispose COMPLETE', {});
    // #endregion
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.interactive && widget.onTap != null) {
      final RenderBox box = context.findRenderObject() as RenderBox;
      final localPosition = box.globalToLocal(details.globalPosition);
      widget.onTap!(localPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadImage,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_image == null) {
      return const Center(
        child: Text('No image loaded'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate image bounds when container size changes
        if (_image != null && (_containerSize == null || _containerSize != constraints.biggest)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _image != null) {
              final newBounds = VenueMapWidget.calculateImageBounds(_image!, constraints.biggest);
              setState(() {
                _containerSize = constraints.biggest;
              });
              // Notify parent of bounds change
              widget.onImageBoundsChanged?.call(newBounds);
            }
          });
        }
        
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: GestureDetector(
            onTapDown: widget.interactive ? _handleTapDown : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image - will resize smoothly via CustomPainter when container size changes
                // CustomPainter automatically repaints with new size, no reload needed
                CustomPaint(
                  painter: _MapPainter(_image!),
                  child: Container(),
                ),
                // Overlays (pins, etc.)
                ...widget.overlays,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  final ui.Image image;

  _MapPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scaling to fit image while maintaining aspect ratio
    final imageAspectRatio = image.width / image.height;
    final canvasAspectRatio = size.width / size.height;

    double drawWidth, drawHeight, offsetX, offsetY;

    if (imageAspectRatio > canvasAspectRatio) {
      // Image is wider - fit to width
      drawWidth = size.width;
      drawHeight = size.width / imageAspectRatio;
      offsetX = 0;
      offsetY = (size.height - drawHeight) / 2;
    } else {
      // Image is taller - fit to height
      drawHeight = size.height;
      drawWidth = size.height * imageAspectRatio;
      offsetX = (size.width - drawWidth) / 2;
      offsetY = 0;
    }

    final rect = Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => oldDelegate.image != image;
}

