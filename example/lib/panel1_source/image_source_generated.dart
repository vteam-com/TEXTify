import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:textify_dashboard/panel1_source/update_character_definitions.dart';
import 'package:textify_dashboard/widgets/gap.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

import 'debounce.dart';
import 'image_generator_input.dart';
import 'panel_step1_content.dart';

ImageGeneratorInput imageSettings = ImageGeneratorInput.empty();

ImageGeneratorInput lastImageSettingsUseForImageSource =
    ImageGeneratorInput.empty();

/// This widget is responsible for displaying and managing the settings of the application.
/// It includes controls for font size and font selection, as well as a preview of the text.
/// The widget adapts its layout based on the screen size, displaying the controls and preview
/// side by side on larger screens and stacked on smaller screens.
///
/// The [onImageChanged] callback is triggered when the font size is changed, and the
/// [onSelectedFontChanged] callback is triggered when a new font is selected.
///
/// This widget is designed to be flexible and easy to use, making it simple to integrate
/// into any Flutter application that requires user-adjustable text settings.
class ImageSourceGenerated extends StatefulWidget {
  const ImageSourceGenerated({
    super.key,
    required this.transformationController,
    required this.onImageChanged,
  });

  final Function(
    ui.Image? image,
    List<String> expectedCharacters,
    String fontName,
    bool includeSpaceDetections,
  ) onImageChanged;

  final TransformationController transformationController;

  @override
  State<ImageSourceGenerated> createState() => _ImageSourceGeneratedState();
}

class _ImageSourceGeneratedState extends State<ImageSourceGenerated> {
  // The list of available fonts
  List<String> availableFonts = [
    'Arial',
    'Courier',
    'Helvetica',
    'Times New Roman',
  ];

  Debouncer debouncer = Debouncer(const Duration(milliseconds: 700));
  Debouncer debouncerGenerateImage =
      Debouncer(const Duration(milliseconds: 400));

  final TextEditingController _textControllerLine1 = TextEditingController();
  final TextEditingController _textControllerLine2 = TextEditingController();
  final TextEditingController _textControllerLine3 = TextEditingController();

  // The image that will be use for detecting the text
  ui.Image? _imageGenerated;

  @override
  void initState() {
    super.initState();

    loadSavedText().then((_) {
      setState(() {
        inputHasChanged();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // adapt to screen size layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardInputs(),
        Expanded(
          child: PanelStep1Content(
            top: _buildActionButtons(),
            center: _imageGenerated == null
                ? Center(child: Text('Loading...'))
                : CustomInteractiveViewer(
                    transformationController: widget.transformationController,
                    child: RawImage(
                      image: _imageGenerated,
                      width: _imageGenerated!.width.toDouble(),
                      height: _imageGenerated!.height.toDouble(),
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Builds the input dashboard, for customizing, FontSize,FontFamily and text input.
  Widget _buildDashboardInputs() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                buildFontSizeSlider(),
                gap(),
                buildPickFont(),
              ],
            ),
          ),
          gap(),
          Expanded(
            child: Column(
              children: [
                buildTextInputLine1(),
                gap(),
                buildTextInputLine2(),
                gap(),
                buildTextInputLine3(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the slider for font size adjustment.
  Widget buildFontSizeSlider() {
    return Row(
      children: [
        SizedBox(
          width: 80, // Set a fixed width for the caption
          child: Text(
            'FontSize ${imageSettings.fontSize}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Expanded(
          child: Slider(
            value: imageSettings.fontSize.toDouble(),
            min: 10,
            max: 100,
            divisions: 100,
            label: imageSettings.fontSize.toString(),
            onChanged: (value) {
              setState(() {
                // this widget we need to call setState in order to show the UI animation of the slider
                imageSettings.fontSize = value.round().toDouble();
                inputHasChanged();
              });
            },
          ),
        ),
      ],
    );
  }

  /// Builds the dropdown for font selection.
  Widget buildPickFont() {
    return Row(
      children: [
        const SizedBox(
          width: 100, // Set a fixed width for the caption
          child: Text('Type', style: TextStyle(fontSize: 16)),
        ),
        DropdownButton<String>(
          value: imageSettings.selectedFont,
          items: availableFonts.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              imageSettings.selectedFont = newValue;
              saveText('font', newValue);
              inputHasChanged();
            }
          },
        ),
      ],
    );
  }

  /// Builds a TextField for text input.
  Widget buildTextInputLine1() {
    return TextField(
      controller: _textControllerLine1,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter text for line 1',
        labelText: 'Line 1',
      ),
      onChanged: (text) {
        imageSettings.defaultTextLine1 = text;
        saveText('textLine1', text);
        inputHasChanged();
      },
    );
  }

  /// Builds a TextField for text input.
  Widget buildTextInputLine2() {
    return TextField(
      controller: _textControllerLine2,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter text for line 2',
        labelText: 'Line 2',
      ),
      onChanged: (text) {
        imageSettings.defaultTextLine2 = text;
        saveText('textLine2', text);
        inputHasChanged();
      },
    );
  }

  /// Builds a TextField for text input.
  Widget buildTextInputLine3() {
    return TextField(
      controller: _textControllerLine3,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter text for line 3',
        labelText: 'Line 3',
      ),
      onChanged: (text) {
        imageSettings.defaultTextLine3 = text;
        saveText('textLine3', text);
        inputHasChanged();
      },
    );
  }

  Future<void> loadSavedText() async {
    final prefs = await SharedPreferences.getInstance();
    imageSettings.selectedFont = prefs.getString('font') ?? 'Arial';
    final textLine1 =
        prefs.getString('textLine1') ?? imageSettings.defaultTextLine1;
    final textLine2 =
        prefs.getString('textLine2') ?? imageSettings.defaultTextLine2;
    final textLine3 =
        prefs.getString('textLine3') ?? imageSettings.defaultTextLine2;
    setState(() {
      _textControllerLine1.text = textLine1;
      _textControllerLine2.text = textLine2;
      _textControllerLine3.text = textLine3;
      imageSettings.defaultTextLine1 = textLine1;
      imageSettings.defaultTextLine2 = textLine2;
      imageSettings.defaultTextLine3 = textLine3;
      imageSettings.lastUpdated = DateTime.now();
    });
  }

  bool containsSpaces(List<String> linesOfText) {
    for (final line in linesOfText) {
      if (line.contains(' ')) {
        return true;
      }
    }
    return false;
  }

  String reduceSpaces(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ');
  }

  void notify() {
    debouncer.run(() {
      final List<String> expectedLinesOfText = [
        reduceSpaces(_textControllerLine1.text),
        reduceSpaces(_textControllerLine2.text),
        reduceSpaces(_textControllerLine3.text),
      ];

      widget.onImageChanged(
        _imageGenerated,
        expectedLinesOfText,
        imageSettings.selectedFont,
        containsSpaces(expectedLinesOfText),
      );
    });
  }

  void inputHasChanged() {
    debouncerGenerateImage.run(() {
      _generateImage();
    });
  }

  void resetContent() async {
    imageSettings = ImageGeneratorInput.empty();
    _textControllerLine1.text = imageSettings.defaultTextLine1;
    _textControllerLine2.text = imageSettings.defaultTextLine2;
    _textControllerLine3.text = imageSettings.defaultTextLine3;

    // Save the reset text
    saveText('textLine1', imageSettings.defaultTextLine1);
    saveText('textLine2', imageSettings.defaultTextLine2);
    saveText('textLine3', imageSettings.defaultTextLine3);

    // Let the parent know Trigger image regeneration
    setState(() {
      _generateImage();
    });
  }

  void switchToRegenerateTemplatesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterGenerationScreen(
          availableFonts: availableFonts,
          onComplete: () {
            resetContent();
          },
        ),
      ),
    );
  }

  Future<void> saveText(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: OutlinedButton(
            onPressed: resetContent,
            child: const Text('Reset'),
          ),
        ),
        gap(),
        SizedBox(
          width: 150,
          child: OutlinedButton(
            onPressed: switchToRegenerateTemplatesScreen,
            child: const Text('Regenerate'),
          ),
        ),
      ],
    );
  }

  /// Builds a quick preview of the text with the selected font and size.
  Future<void> _generateImage() async {
    if (lastImageSettingsUseForImageSource != imageSettings) {
      await createColorImageUsingTextPainter(
        fontFamily: imageSettings.selectedFont,
        backgroundColor: imageSettings.imageBackgroundColor,
        text1: _textControllerLine1.text,
        textColor1: imageSettings.imageTextColorAlphabet,
        text2: _textControllerLine2.text,
        textColor2: imageSettings.imageTextColorAlphabet,
        text3: _textControllerLine3.text,
        textColor3: imageSettings.imageTextColorNumbers,
        fontSize: imageSettings.fontSize.toInt(),
      ).then((newImageSource) {
        _imageGenerated = newImageSource;
        imageSettings.lastUpdated = DateTime.now();
        lastImageSettingsUseForImageSource = imageSettings.clone();
        notify();
      });
    }
  }
}

Future<ui.Image> createColorImageSingleCharacter({
  required final int imageWidth,
  required final int imageHeight,
  required final String character,
  // Font
  required final String fontFamily,
  required final int fontSize,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas newCanvas = ui.Canvas(recorder);

  final ui.Paint paint = ui.Paint();
  paint.color = Colors.white;
  paint.style = ui.PaintingStyle.fill;

  newCanvas.drawRect(
    ui.Rect.fromPoints(
      const ui.Offset(0.0, 0.0),
      ui.Offset(
        imageWidth.toDouble(),
        imageHeight.toDouble(),
      ),
    ),
    paint,
  );

  TextPainter textPainter = myDrawText(
    paint: paint,
    width: imageWidth,
    text: character,
    color: Colors.black,
    fontSize: fontSize,
    fontFamily: fontFamily,
  );

  textPainter.paint(
    newCanvas,
    Offset(0, 0),
  );

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(imageWidth, imageHeight);
  return image;
}

Future<ui.Image> createColorImageUsingTextPainter({
  required final Color backgroundColor,
  // text 1
  required final String text1,
  required final Color textColor1,
  // text 2
  required final String text2,
  required final Color textColor2,
  // text 3
  required final String text3,
  required final Color textColor3,
  // Font
  required final String fontFamily,
  required final int fontSize,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas newCanvas = ui.Canvas(recorder);

  final ui.Paint paint = ui.Paint();
  paint.color = backgroundColor;
  paint.style = ui.PaintingStyle.fill;

  const letterSpacing = 4;

  final int maxWidthLine1 = text1.length * (fontSize + letterSpacing);
  final int maxWidthLine2 = text2.length * (fontSize + letterSpacing);
  final int maxWidthLine3 = text2.length * (fontSize + letterSpacing);

  const int padding = 20;
  final int imageWidth = padding +
      max(
        1,
        max(
          max(
            maxWidthLine1,
            maxWidthLine2,
          ),
          maxWidthLine3,
        ),
      );
  final int imageHeight = padding + (5 * fontSize);

  newCanvas.drawRect(
    ui.Rect.fromPoints(
      const ui.Offset(0.0, 0.0),
      ui.Offset(
        imageWidth.toDouble(),
        imageHeight.toDouble(),
      ),
    ),
    paint,
  );

  // Line 1
  TextPainter textPainter = myDrawText(
    paint: paint,
    width: imageWidth,
    text: text1,
    color: textColor1,
    fontSize: fontSize,
    fontFamily: fontFamily,
  );
  textPainter.paint(
    newCanvas,
    Offset(padding.toDouble(), padding.toDouble()),
  );

  // Line 2
  TextPainter textPainter2 = myDrawText(
    paint: paint,
    width: imageWidth,
    text: text2,
    color: textColor2,
    fontSize: fontSize,
    fontFamily: fontFamily,
  );
  textPainter2.paint(
    newCanvas,
    Offset(padding.toDouble(), 2 * fontSize.toDouble()),
  );

  // Line 3
  TextPainter textPainter3 = myDrawText(
    paint: paint,
    width: imageWidth,
    text: text3,
    color: textColor3,
    fontSize: fontSize,
    fontFamily: fontFamily,
  );
  textPainter3.paint(
    newCanvas,
    Offset(padding.toDouble(), 4 * fontSize.toDouble()),
  );

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(imageWidth, imageHeight);
  return image;
}

TextPainter myDrawText({
  required final Paint paint,
  required final Color color,
  required final String text,
  required final int fontSize,
  required final String fontFamily,
  required final int width,
  int letterSpacing = 4,
}) {
  paint.color = color;

  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        letterSpacing: letterSpacing.toDouble(),
        fontSize: fontSize.toDouble(),
        fontFamily: fontFamily,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
  );

  textPainter.layout(
    maxWidth: width.toDouble(),
  );
  return textPainter;
}
