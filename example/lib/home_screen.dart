import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  Debouncer debouncer = Debouncer(const Duration(milliseconds: 1000));

  final Settings _settings = Settings();

  ui.Image? _imageSource;
  String _fontName = '';
  List<String> _stringsExpectedToBeFoundInTheImage = [];
  ViewAs viewAs = ViewAs.matrix;

  String _textFound = '';

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();

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
                  content: PanelSteps(
                    imageSource: _imageSource,
                    regions: _textify.regions,
                    kernelSizeDilate: _textify.dilatingSize,
                    displayChoicesChanged: (
                      final int sizeDilate,
                    ) {
                      setState(
                        () {
                          _textify.dilatingSize = max(0, sizeDilate);
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
                        _textify.dilatingSize = 22;
                        _transformationController.value = Matrix4.identity();
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

    final String theTextFound =
        await _textify.getTextFromImage(image: _imageSource!);

    if (mounted) {
      setState(() {
        _textFound = theTextFound;
      });
    }
  }
}
