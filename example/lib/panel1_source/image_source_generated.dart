import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/generate_samples/generate_image.dart';
import 'package:textify_dashboard/generate_samples/generate_unit_test_sample_images.dart';
import 'package:textify_dashboard/panel1_source/update_character_definitions.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

import 'debounce.dart';
import 'image_generator_input.dart';
import 'panel1_content.dart';

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
          child: PanelStepContent(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            // Slider  [====================]
            //
            // Font    | Colors Foreground
            //         | Colors Background
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildFontSizeSlider(),
                Wrap(
                  spacing: 20,
                  children: [
                    IntrinsicWidth(child: buildPickFont()),
                    IntrinsicWidth(
                      child: Column(
                        children: [
                          pickColor(context, 'Foreground',
                              imageSettings.imageForegroundColor,
                              (Color color) async {
                            setState(() {
                              imageSettings.imageForegroundColor = color;
                              inputHasChanged();
                            });
                          }),
                          pickColor(context, 'Background',
                              imageSettings.imageBackgroundColor,
                              (Color color) async {
                            setState(() {
                              imageSettings.imageBackgroundColor = color;
                              inputHasChanged();
                            });
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                buildTextInputLine1(),
                buildTextInputLine2(),
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

  static Widget pickColor(
    final BuildContext context,
    final String text,
    Color color,
    Function(Color) onSelected,
  ) {
    return TextButton(
      key: Key('pickColor_$text'),
      onPressed: () => _pickColorDialog(context, color, (Color color) {
        onSelected(color);
      }),
      child: Row(
        spacing: 5,
        children: [
          Text(text),
          Container(
            // width: 60,
            height: 20,
            padding: EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.grey),
            ),
            child: Text(
              color.toARGB32().toRadixString(16).substring(2).toUpperCase(),
              style: TextStyle(color: getContrastColor(color)),
            ),
          ),
        ],
      ),
    );
  }

  static Color getContrastColor(Color backgroundColor) {
    // Get luminance directly from the color
    double luminance = backgroundColor.computeLuminance();

    // Return black for bright colors, white for dark colors
    return luminance > 0.5 ? Colors.black : Colors.white;
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

  void switchToGenerateUnitTestSamplesScreen() {
    Textify textify = Textify();
    textify.init();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerateImagesForUnitTestsScreen(
          textify: textify,
        ),
      ),
    );
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
      spacing: 10,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: OutlinedButton(
            onPressed: resetContent,
            child: const Text('Reset'),
          ),
        ),
        SizedBox(
          width: 150,
          child: OutlinedButton(
            onPressed: switchToGenerateUnitTestSamplesScreen,
            child: const Text('UnitTests'),
          ),
        ),
        SizedBox(
          width: 150,
          child: OutlinedButton(
            onPressed: switchToRegenerateTemplatesScreen,
            child: const Text('Templatize'),
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
        textColor1: imageSettings.imageForegroundColor,
        text2: _textControllerLine2.text,
        textColor2: imageSettings.imageForegroundColor,
        text3: _textControllerLine3.text,
        textColor3: imageSettings.imageForegroundColor,
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

void _pickColorDialog(
  final BuildContext context,
  final Color color,
  final Function(Color) onSelected,
) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: (color) {
              onSelected(color);
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Got it'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
