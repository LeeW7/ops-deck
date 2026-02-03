import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/screenshot_attachment.dart';

/// A widget that displays a grid of screenshots with add/remove/retry functionality.
class ScreenshotPicker extends StatelessWidget {
  final List<ScreenshotAttachment> screenshots;
  final int maxScreenshots;
  final bool canAddMore;
  final Function(String localPath) onAdd;
  final Function(String id) onRemove;
  final Function(String id) onRetry;

  const ScreenshotPicker({
    super.key,
    required this.screenshots,
    required this.maxScreenshots,
    required this.canAddMore,
    required this.onAdd,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Screenshot grid
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Existing screenshots
            ...screenshots.map((screenshot) => _ScreenshotThumbnail(
                  screenshot: screenshot,
                  onRemove: () => onRemove(screenshot.id),
                  onRetry: () => onRetry(screenshot.id),
                )),
            // Add button (if not at max)
            if (canAddMore)
              _AddScreenshotButton(
                onTap: () => _showImageSourceSheet(context),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Hint text
        Center(
          child: Text(
            canAddMore
                ? 'Tap to add up to $maxScreenshots screenshots (PNG, JPG)'
                : 'Maximum $maxScreenshots screenshots reached',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFF8B949E),
            ),
          ),
        ),
      ],
    );
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImageSourceBottomSheet(
        onCameraTap: () async {
          Navigator.pop(context);
          await _pickFromCamera(context);
        },
        onGalleryTap: () async {
          Navigator.pop(context);
          await _pickFromGallery(context);
        },
        onClipboardTap: () async {
          Navigator.pop(context);
          await _pasteFromClipboard(context);
        },
      ),
    );
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      onAdd(image.path);
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      onAdd(image.path);
    }
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        // Check if it's a file path
        final path = clipboardData!.text!;
        if (await File(path).exists()) {
          onAdd(path);
          return;
        }
      }

      // Try getting image data from clipboard (works on some platforms)
      // For now, show a message that clipboard paste requires a file path
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Paste an image file path or use camera/gallery',
              style: TextStyle(fontFamily: 'monospace'),
            ),
            backgroundColor: Color(0xFF30363D),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not paste from clipboard: $e',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    }
  }
}

/// Thumbnail for a single screenshot with remove/retry buttons
class _ScreenshotThumbnail extends StatelessWidget {
  final ScreenshotAttachment screenshot;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const _ScreenshotThumbnail({
    required this.screenshot,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: screenshot.status == UploadStatus.failed
              ? const Color(0xFFDA3633)
              : const Color(0xFF30363D),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          Opacity(
            opacity: screenshot.isUploading ? 0.7 : 1.0,
            child: Image.file(
              File(screenshot.localPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF161B22),
                child: const Icon(
                  Icons.broken_image,
                  color: Color(0xFF8B949E),
                ),
              ),
            ),
          ),
          // Upload progress indicator
          if (screenshot.isUploading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                color: const Color(0xFF0D1117),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: screenshot.uploadProgress ?? 0.5,
                  child: Container(
                    color: const Color(0xFF00FF41),
                  ),
                ),
              ),
            ),
          // Success checkmark
          if (screenshot.isUploaded)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF238636),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          // Error indicator with retry
          if (screenshot.status == UploadStatus.failed)
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDA3633),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 12,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'Retry',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Remove button (always visible)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xE6DA3633), // 0xDA3633 with 90% opacity
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add button for adding new screenshots
class _AddScreenshotButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddScreenshotButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const DashedBorderContainer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 24,
              color: Color(0xFF8B949E),
            ),
            SizedBox(height: 4),
            Text(
              'ADD',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Color(0xFF8B949E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Container with dashed border effect
class DashedBorderContainer extends StatelessWidget {
  final Widget child;

  const DashedBorderContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF30363D)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );

    // Draw dashed border
    final pathMetrics = Path()..addRRect(rect);
    for (final metric in pathMetrics.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashWidth).clamp(0, metric.length);
        path.addPath(
          metric.extractPath(start, end.toDouble()),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom sheet for selecting image source
class _ImageSourceBottomSheet extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onClipboardTap;

  const _ImageSourceBottomSheet({
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onClipboardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF30363D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            'ADD SCREENSHOT',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B949E),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          // Options
          _ImageSourceOption(
            icon: Icons.camera_alt,
            title: 'Take Photo',
            description: 'Capture a new screenshot with camera',
            onTap: onCameraTap,
          ),
          const SizedBox(height: 8),
          _ImageSourceOption(
            icon: Icons.photo_library,
            title: 'Choose from Gallery',
            description: 'Select an existing image',
            onTap: onGalleryTap,
          ),
          const SizedBox(height: 8),
          _ImageSourceOption(
            icon: Icons.content_paste,
            title: 'Paste from Clipboard',
            description: 'Use a recently copied image',
            onTap: onClipboardTap,
          ),
          const SizedBox(height: 8),
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B949E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single option in the image source bottom sheet
class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: const Color(0xFF58A6FF),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE6EDF3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
