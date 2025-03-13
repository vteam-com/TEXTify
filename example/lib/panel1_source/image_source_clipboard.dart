import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/image_viewer.dart';
import 'debounce.dart';
import 'panel_step_content.dart';

/// Provides functionality to retrieve images from the system clipboard.
///
/// This file contains the [ImageSourceClipboard] class, which is responsible for
/// accessing and processing image data that has been copied to the clipboard.
/// It's particularly useful in scenarios where users want to quickly import
/// images into the application without going through a file selection process.
///
/// The [ImageSourceClipboard] class likely implements or extends a more general
/// image source interface, allowing it to be used interchangeably with other
/// image sources like file pickers or camera inputs.
///
/// Usage:
/// ```dart
/// final clipboardSource = ImageSourceClipboard();
/// final image = await clipboardSource.getImage();
/// if (image != null) {
///   // Process the image
/// } else {
///   // Handle case where no image is on the clipboard
/// }
/// ```
///
/// Note: The actual implementation details would depend on the specific
/// methods and properties of the ImageSourceClipboard class, which are not
/// visible in the provided context.
///
/// This class may use platform-specific code to interact with the clipboard,
/// so it might have different implementations for various platforms (iOS,
/// Android, web, desktop, etc.).
///
/// Limitations:
/// - May not work on all platforms due to clipboard access restrictions.
/// - The clipboard must contain valid image data for this to work.
/// - Performance may vary depending on the size and format of the clipboard image.
class ImageSourceClipboard extends StatefulWidget {
  const ImageSourceClipboard({
    super.key,
    required this.transformationController,
    required this.onImageChanged,
  });

  final Function(ui.Image?) onImageChanged;
  final TransformationController transformationController;

  @override
  State<ImageSourceClipboard> createState() => _ImageSourceClipboardState();
}

class _ImageSourceClipboardState extends State<ImageSourceClipboard> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadSavedImage();
  }

  @override
  Widget build(BuildContext context) {
    return PanelStepContent(
      // Paste button
      left: IconButton(
        icon: const Icon(Icons.paste),
        onPressed: () async {
          final Uint8List? bytes = await Pasteboard.image;
          if (bytes != null) {
            if (context.mounted) {
              _clipboardToImage(context, bytes);
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No image found in clipboard.'),
                ),
              );
            }
          }
        },
      ),
      // Display image
      center: _buildDisplayImage(),
      // Clear button
      right: IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () async {
          if (mounted) {
            await _updateImageFromBytes(Uint8List(0));
            setState(() {});
          }
          widget.onImageChanged(null); // Notify image cleared
        },
      ),
    );
  }

  Widget _buildDisplayImage() {
    return _image == null
        ? const Center(child: Text('No image pasted'))
        : CustomInteractiveViewer(
            transformationController: widget.transformationController,
            child: ImageViewer(
              image: _image!,
            ),
          );
  }

  void _clipboardToImage(
    final BuildContext context,
    final Uint8List bytes,
  ) async {
    try {
      // Update state with image bytes from clipboard
      await _updateImageFromBytes(bytes);
      setState(() {});

      // Notify the widget's parent about the image change
      widget.onImageChanged(_image);

      // Save the image bytes to SharedPreferences
      await _saveImageToPrefs(bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decode image from clipboard.'),
          ),
        );
      }
    }
  }

  Future<void> _loadSavedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedImage = prefs.getString('clipboard_image');
    if (savedImage != null) {
      final Uint8List savedImageBytes = base64Decode(savedImage);
      await _updateImageFromBytes(savedImageBytes);
      setState(() {});
      widget.onImageChanged(_image);
    }
  }

  Future<void> _saveImageToPrefs(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clipboard_image', base64Encode(bytes));
  }

  Future<void> _updateImageFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) {
      _image = null;
    } else {
      _image = await fromBytesToImage(bytes);
    }
  }
}
