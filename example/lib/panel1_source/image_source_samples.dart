import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

import 'debounce.dart';
import 'panel1_content.dart';

class ImageSourceSamples extends StatefulWidget {
  const ImageSourceSamples({
    super.key,
    required this.transformationController,
    required this.onImageChanged,
  });

  final Function(
    ui.Image?,
    List<String> expectedStrings,
    bool includeSpaceDetection,
  ) onImageChanged;
  final TransformationController transformationController;

  @override
  State<ImageSourceSamples> createState() => _ImageSourceSamplesState();
}

class _ImageSourceSamplesState extends State<ImageSourceSamples> {
  final List<ImageData> imageFileData = [
    ImageData(
      'generated-odd-colors.png',
      // cspell:disable-next-line
      'ABCDEFGHI\nJKLMNOPQR\nSTUVWXYZ\n01\n23456789',
    ),
    ImageData(
      'black-on-white-rounded.png',
      // cspell:disable-next-line
      'ABCDE\nFGHIJ\nKLMN\nOPQRS\nTUVW\nXYZ',
    ),
    ImageData(
      'black-on-white-typewriter.png',
      // cspell:disable-next-line
      'ABCDEFGH\nIJKLMNOP\nQRSTUVWX\nYZ',
    ),
    ImageData(
      'back-on-white-the_example_text.png',
      // cspell:disable-next-line
      'THEEXAMPLETEXT',
    ),
    ImageData(
      'classy.png',
      // cspell:disable-next-line
      'ABCDE\nFGHIJK\nLMNOP\nQRSTUV\nWXYZ',
    ),
    ImageData(
      'upper-case-alphabet-times-700x490.jpg',
      // cspell:disable-next-line
      'ABCDEFG\nHIJKLMN\nOPQRSTU\nVWXYZ',
    ),
    ImageData(
      'lines-circles.png',
      // cspell:disable-next-line
      'HELLO THIS IS A TEST IN UPPER CASE.\nThis is a normal phrase with number like 123,456.89\nDATES\n2020-01-02\n2021/03/04\n2022.05.05\nEnds\nHere',
    ),
    ImageData(
      'color-on-white-gummy.png',
      // cspell:disable-next-line
      'ABCDEF\nGHIJKL\nMNOPQ\nRSTUV\nWXYZ',
    ),
    ImageData(
      'bank-statement.png',
      '',
    ),
    ImageData(
      'bank-statement-template-27.webp',
      '',
    ),
    ImageData(
      'the-quick-brown-fox.png',
      'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\nThe quick brown fox jumps over the lazy dog\n2025-12-31',
    ),
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLastIndex();
  }

  @override
  Widget build(BuildContext context) {
    return PanelStepContent(
      top: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        spacing: 20,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentIndex > 0
                ? () {
                    _changeIndex(_currentIndex - 1);
                  }
                : null,
          ),
          Text('Sample #$_currentIndex'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _currentIndex < imageFileData.length - 1
                ? () {
                    _changeIndex(_currentIndex + 1);
                  }
                : null,
          ),
        ],
      ),
      center: CustomInteractiveViewer(
        transformationController: widget.transformationController,
        child: Image.asset(
          getSampleAssetName(_currentIndex),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  List<String> getSampleExpectedText(int index) {
    index = index.clamp(0, imageFileData.length - 1);
    if (imageFileData[index].expected.isEmpty) {
      return [];
    } else {
      return imageFileData[index].expected.split('\n');
    }
  }

  String getSampleAssetName(int index) {
    index = index.clamp(0, imageFileData.length - 1);
    return 'assets/samples/${imageFileData[index].file}';
  }

  Future<ui.Image> getUiImageFromAsset(String assetPath) async {
    // Load the asset as a byte array
    final ByteData data = await rootBundle.load(assetPath);
    return fromBytesToImage(data.buffer.asUint8List());
  }

  void _changeIndex(int newIndex) {
    _saveLastIndex();
    if (mounted) {
      setState(() {
        _currentIndex = newIndex;
        _loadCurrentImage();
      });
    }
  }

  void _loadCurrentImage() async {
    final ui.Image image =
        await getUiImageFromAsset(getSampleAssetName(_currentIndex));

    widget.onImageChanged(image, getSampleExpectedText(_currentIndex), true);
  }

  Future<void> _loadLastIndex() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentIndex = prefs.getInt('last_sample_index') ?? 0;
      });
    }
    _loadCurrentImage();
  }

  Future<void> _saveLastIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sample_index', _currentIndex);
  }
}

class ImageData {
  ImageData(this.file, this.expected);

  final String expected;
  final String file;
}
