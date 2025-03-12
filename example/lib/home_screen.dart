import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:textify/matrix.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/panel1_source/debounce.dart';
import 'package:textify_dashboard/panel1_source/image_source_selector.dart';
import 'package:textify_dashboard/panel1_source/panel_content.dart';
import 'package:textify_dashboard/panel2_steps/panel_steps.dart';
import 'package:textify_dashboard/panel3_artifacts/panel_artifacts_found.dart';
import 'package:textify_dashboard/settings.dart';
import 'package:textify_dashboard/widgets/display_artifact.dart';
import 'panel4_results/panel_matched_artifacts.dart';

///
class HomeScreen extends StatefulWidget {
  ///
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Textify _textify = Textify();

  // The image that will be use for detecting the text
  ui.Image? _imageBlackOnWhite;

  Debouncer debouncer = Debouncer(const Duration(milliseconds: 1000));

  final Settings _settings = Settings();

  bool _erodeFirst = true;
  late int _kernelSizeErode;
  late int _kernelSizeDilate;

  ui.Image? _imageSource;
  String _fontName = '';
  List<String> _stringsExpectedToBeFoundInTheImage = [];
  ViewAs viewAs = ViewAs.original;

  String _textFound = '';

  final TransformationController _transformationController =
      TransformationController();

  void _initializeSettings() {
    _kernelSizeErode = 0;
    _kernelSizeDilate = 0;
    _imageBlackOnWhite = null;
  }

  @override
  void initState() {
    super.initState();
    _initializeSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _textify.init();
      _convertImageToText();
    });
    _settings.load();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final String textFoundSingleString = _textFound.replaceAll('\n', ' ');

    return Scaffold(
      backgroundColor: colorScheme.primaryContainer,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: ExpansionPanelList(
              expandedHeaderPadding: const EdgeInsets.all(0),
              materialGapSize: 2,
              expansionCallback: (int index, bool isExpanded) {
                setState(() {
                  switch (index) {
                    case 0:
                      _settings.isExpandedSource = isExpanded;
                    case 1:
                      _settings.isExpandedOptimized = isExpanded;
                    case 2:
                      _settings.isExpandedArtifactFound = isExpanded;
                    case 3:
                      _settings.isExpandedResults = isExpanded;
                  }
                });
                _settings.save();
              },
              children: [
                //
                // Panel 1 - Input Source
                //
                buildExpansionPanel(
                  titleLeft: 'TEXTIFY',
                  titleCenter: 'Source',
                  titleRight: '',
                  isExpanded: _settings.isExpandedSource,
                  content: ImageSourceSelector(
                    transformationController: _transformationController,
                    onSourceChanged: (
                      final ui.Image? newImage,
                      final List<String> expectedText,
                      final String fontName,
                      final bool includeSpaceDetection,
                    ) {
                      _imageSource = newImage;
                      _stringsExpectedToBeFoundInTheImage = expectedText
                          .where((str) => str.isNotEmpty)
                          .toList(); // remove empty entries
                      _fontName = fontName;
                      _textify.includeSpaceDetections = includeSpaceDetection;
                      _convertImageToText();
                    },
                  ),
                ),

                //
                // Panel 2 - Input optimized image
                //
                buildExpansionPanel(
                  titleLeft: 'Steps',
                  titleCenter: _getDimensionOfImageSource(_imageSource),
                  titleRight: '',
                  isExpanded: _settings.isExpandedOptimized,
                  content: panelOptimizedImage(
                    imageBlackOnWhite: _imageBlackOnWhite,
                    regions: _textify.regions,
                    erodeFirst: _erodeFirst,
                    kernelSizeErode: _kernelSizeErode,
                    kernelSizeDilate: _kernelSizeDilate,
                    displayChoicesChanged: (
                      final bool erodeFirst,
                      final int sizeErode,
                      final int sizeDilate,
                    ) {
                      setState(
                        () {
                          _erodeFirst = erodeFirst;
                          _kernelSizeErode = max(0, sizeErode);
                          _kernelSizeDilate = max(0, sizeDilate);
                          _imageBlackOnWhite = null;
                          debouncer.run(
                            () {
                              _convertImageToText();
                            },
                          );
                        },
                      );
                    },
                    onReset: () {
                      // Reset
                      setState(() {
                        _initializeSettings();
                      });
                    },
                    transformationController: _transformationController,
                  ),
                ),

                //
                // Panel 3 - Bands and Artifacts
                //
                buildExpansionPanel(
                  titleLeft: '${_textify.bands.length} Bands',
                  titleCenter: '${_textify.count} Artifacts',
                  titleRight:
                      '${NumberFormat.decimalPattern().format(_textify.duration)}ms',
                  isExpanded: _settings.isExpandedArtifactFound,
                  content: panelArtifactFound(
                    textify: _textify,
                    transformationController: _transformationController,
                    viewAs: viewAs,
                    onChangeView: (ViewAs viewAs) {
                      setState(() {
                        this.viewAs = viewAs;
                      });
                    },
                  ),
                ),

                //
                // Panel 4 - Results / Text
                //
                buildExpansionPanel(
                  titleLeft: 'Results',
                  titleCenter: getPercentageText(textFoundSingleString),
                  titleRight: '',
                  isExpanded: _settings.isExpandedResults,
                  content: PanelMatchedArtifacts(
                    font: _fontName,
                    expectedStrings: _stringsExpectedToBeFoundInTheImage,
                    textify: _textify,
                    settings: _settings,
                    onSettingsChanged: () {
                      setState(() {
                        _convertImageToText();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String getPercentageText(String textFoundSingleString) {
    String percentage = '${textFoundSingleString.length} characters';

    if (_stringsExpectedToBeFoundInTheImage.isNotEmpty) {
      percentage += ' ';
      percentage += compareStringPercentage(
        _stringsExpectedToBeFoundInTheImage.join(),
        _textFound.replaceAll('\n', ''),
      ).toStringAsFixed(0);
      percentage += '%';
    }
    return percentage;
  }

  void _clearState() {
    if (mounted) {
      setState(() {
        _imageBlackOnWhite = null;
        _textify.applyDictionary = _settings.applyDictionary;
        _textFound = '';
      });
    }
  }

  String _getDimensionOfImageSource(imageSource) {
    if (imageSource == null) {
      return '';
    }
    return '${imageSource!.width} x ${imageSource!.height}';
  }

  Future<void> _convertImageToText() async {
    if (_imageSource == null) {
      _clearState();
      return;
    }

    // Convert color image source to a grid of on=ink/off=paper
    ui.Image tmpImageBlackOnWhite = await imageToGrayScale(_imageSource!);

    if (_erodeFirst) {
      if (_kernelSizeErode > 0) {
        tmpImageBlackOnWhite = await erode(
          tmpImageBlackOnWhite,
          kernelSize: _kernelSizeErode,
        );
      }

      if (_kernelSizeDilate > 0) {
        tmpImageBlackOnWhite = await dilate(
          inputImage: tmpImageBlackOnWhite,
          kernelSize: _kernelSizeDilate,
        );
      }
    } else {
      if (_kernelSizeDilate > 0) {
        tmpImageBlackOnWhite = await dilate(
          inputImage: tmpImageBlackOnWhite,
          kernelSize: _kernelSizeDilate,
        );
      }

      if (_kernelSizeErode > 0) {
        tmpImageBlackOnWhite = await erode(
          tmpImageBlackOnWhite,
          kernelSize: _kernelSizeErode,
        );
      }
    }
    final String theTextFound = await _textify.getTextFromMatrix(
      imageAsMatrix: await Matrix.fromImage(tmpImageBlackOnWhite),
    );

    if (mounted) {
      setState(() {
        _imageBlackOnWhite = tmpImageBlackOnWhite;
        _textFound = theTextFound;
      });
    }
  }
}
