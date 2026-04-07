import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/background_ocr.dart';

class TextifyingImage extends StatefulWidget {
  const TextifyingImage({
    super.key,
    required this.textify,
    required this.image,
    required this.expectedText,
  });
  final Textify textify;
  final ui.Image image;
  final String expectedText;

  @override
  State<TextifyingImage> createState() => _TextifyingImageState();
}

class _TextifyingImageState extends State<TextifyingImage> {
  bool _isProcessing = false;
  String _extractedText = '';
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  @override
  void didUpdateWidget(TextifyingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image ||
        oldWidget.expectedText != widget.expectedText) {
      _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await processImageWithBackgroundIsolate(
        image: widget.image,
        config: widget.textify.config,
        characterDefinitionsJson: Textify.characterDefinitions.toJsonString(),
      );
      setState(() {
        _extractedText = result.textFound;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _lastError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 20.0),
      );
    }

    if (_lastError.isEmpty) {
      return Text(_extractedText);
    }
    return Text(_lastError);
  }
}
