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
      'ABCDEFGHI\nJKLMNOPQR\nSTUVWXYZ 0123456789',
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
      'THE EXAMPLE TEXT',
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
      'bank_statement.png',
      // cspell:disable-next-line
      'FINO GOLF CLUB, MATOSINHOS\n'
          // cspell:disable-next-line
          'CONTINENTE BOM DIA, MATOSINHOS\n'
          // cspell:disable-next-line
          'WWW.AMAZON.* LS1AK28I5, LUXEMBOURG\n'
          // cspell:disable-next-line
          'REMARKABLE, OSLO\n'
          // cspell:disable-next-line
          'PINGO DOCE MATOSINHO, MATOSINHOS\n'
          // cspell:disable-next-line
          'CONTINENTE BOM DIA, MATOSINHOS\n'
          // cspell:disable-next-line
          'PAD PORT MATO, MATOSINHOS\n'
          // cspell:disable-next-line
          'CASA DAS UTILIDADES, Guimaraes\n'
          // cspell:disable-next-line
          'EUROLOJAMATOSINHOS, MATOSINHOS\n'
          // cspell:disable-next-line
          'CORES SABORES BOLHAO, PORTO\n'
          // cspell:disable-next-line
          'Tuca Cha E Cafe, PORTO',
    ),
    ImageData(
      'bank-statement.png',
      '',
    ),
    ImageData(
      'chase.webp',
      '',
    ),
    ImageData(
      'the-quick-brown-fox.png',
      'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\nThe quick brown fox jumps over the lazy dog\n2025-12-31',
    ),
    // --- 10 generated test images ---
    ImageData(
      'address-block.png',
      '350 MAIN STREET\nSAN FRANCISCO, CA 94105\nUNITED STATES',
    ),
    ImageData(
      'receipt-items.png',
      'ITEM QTY PRICE\nWidget A 3 12.99\nWidget B 1 7.50\nGadget C 2 24.00\nTOTAL 57.48',
    ),
    ImageData(
      'mixed-case-sentence.png',
      'OpenAI Released GPT In 2020.\nVersion 4 Arrived In March 2023.',
    ),
    ImageData(
      'single-line-large.png',
      'WAREHOUSE PICKUP 9AM',
    ),
    ImageData(
      'numbers-grid.png',
      '1001 2002 3003\n4004 5005 6006\n7007 8008 9009',
    ),
    ImageData(
      'small-text-dense.png',
      'Name: John Smith\nDate: 2025-06-15\nReference: TX-98432\nAmount: 1,250.75\nStatus: CONFIRMED',
    ),
    ImageData(
      'uppercase-short-words.png',
      'GO BIG OR GO HOME\nBE THE BEST YOU CAN BE',
    ),
    ImageData(
      'title-case-names.png',
      'Alice Johnson\nBob Williams\nCharlie Brown',
    ),
    ImageData(
      'codes-and-ids.png',
      'ORD-20250615-0042\nSKU: AB12CD34EF56\nLOT: 2025/Q2/BATCH07',
    ),
    ImageData(
      'paragraph-helvetica.png',
      'Payment received on 03/15/2025.\nYour balance is now 0.00 USD.\nThank you for your purchase.',
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
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 20,
        children: [
          OutlinedButton(
            onPressed: _currentIndex > 0
                ? () {
                    _changeIndex(_currentIndex - 1);
                  }
                : null,
            child: const Icon(Icons.arrow_back),
          ),
          Text('Sample\n#${_currentIndex + 1}', textAlign: TextAlign.center),
          OutlinedButton(
            onPressed: _currentIndex < imageFileData.length - 1
                ? () {
                    _changeIndex(_currentIndex + 1);
                  }
                : null,
            child: const Icon(Icons.arrow_forward),
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
