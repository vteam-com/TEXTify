import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:textify/image_helpers.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/background_ocr.dart';
import 'package:textify_dashboard/generate_samples/generate_image.dart';
import 'package:textify_dashboard/panel1_source/debounce.dart';
import 'package:textify_dashboard/panel1_source/panel1_content.dart';
import 'package:textify_dashboard/panel2_steps/display_bands_and_artifacts.dart';
import 'package:textify_dashboard/panel2_steps/panel2_steps_toolbar.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

class PanelSteps extends StatefulWidget {
  const PanelSteps({
    super.key,
    required this.textify,
    required this.imageSource,
    required this.regions,
    required this.excludeLongLines,
    required this.onExcludeLongLinesChanged,
    required this.kernelSizeDilate,
    required this.displayChoicesChanged,
    required this.matchingThreshold,
    required this.onMatchingThresholdChanged,
    required this.maxProcessingTimeMs,
    required this.onMaxProcessingTimeChanged,
    required this.onReset,
    required this.transformationController,
  });
  final Textify textify;
  final ui.Image? imageSource;
  final List<IntRect> regions;
  final bool excludeLongLines;
  final Function(bool) onExcludeLongLinesChanged;
  final int kernelSizeDilate;
  final Function(int) displayChoicesChanged;
  final double matchingThreshold;
  final Function(double) onMatchingThresholdChanged;
  final int maxProcessingTimeMs;
  final Function(int) onMaxProcessingTimeChanged;
  final Function onReset;
  final TransformationController transformationController;

  @override
  State<PanelSteps> createState() => _PanelStepsState();
}

class _PanelStepsState extends State<PanelSteps> {
  bool _isReady = false;
  late ViewAs _viewAs;
  ui.Image? _imageBW;
  ui.Image? imageToDisplay;
  ui.Image? _imageDilated;
  List<IntRect> _regions = [];
  List<List<int>> _regionsHistograms = [];
  bool _showRegions = false;
  bool _showHistograms = false;

  Debouncer debouncer = Debouncer(const Duration(milliseconds: 1000));

  @override
  void initState() {
    super.initState();
    _viewAs = ViewAs.blackAndWhite;
  }

  @override
  void didUpdateWidget(PanelSteps oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageSource != widget.imageSource ||
        oldWidget.kernelSizeDilate != widget.kernelSizeDilate) {
      setState(() {
        _isReady = false;
      });
      updateImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PanelStepContent(
      top: Panel2Toolbar(
        viewAsStep: _viewAs,
        transformationController: widget.transformationController,
        onViewChanged: (ViewAs view) {
          setState(() {
            _viewAs = view;
          });
        },

        //
        // Region
        //
        showRegions: _showRegions,
        onShowRegionsChanged: (value) {
          setState(() {
            _showRegions = value;
          });
        },

        //
        excludeLongLines: widget.excludeLongLines,
        onExcludeLongLinesChanged: widget.onExcludeLongLinesChanged,

        //
        // Histogram
        //
        showHistograms: _showHistograms,
        onShowHistogramsChanged: (value) {
          setState(() {
            _showHistograms = value;
          });
        },

        //
        // Dilate
        //
        kernelSizeDilate: widget.kernelSizeDilate,
        onDelateChanged: widget.displayChoicesChanged,
        matchingThreshold: widget.matchingThreshold,
        onMatchingThresholdChanged: widget.onMatchingThresholdChanged,
        maxProcessingTimeMs: widget.maxProcessingTimeMs,
        onMaxProcessingTimeChanged: widget.onMaxProcessingTimeChanged,

        onReset: widget.onReset,
      ),
      center: centerContent(),
      bottom: buildPanelHeader(
        '${widget.textify.bands.totalArtifacts} Artifacts',
        '',
        '${NumberFormat.decimalPattern().format(widget.textify.duration)}ms',
      ),
    );
  }

  Widget centerContent() {
    if (widget.imageSource == null) {
      return Center(child: Text('No input image'));
    }

    if (_isReady == false) {
      return Center(
        child: CupertinoActivityIndicator(radius: 20.0),
      );
    }

    switch (_viewAs) {
      case ViewAs.blackAndWhite:
        imageToDisplay = _imageBW;
        return buildInteractiveImageViewer(
          drawRectanglesOnImage(imageToDisplay!),
          widget.transformationController,
        );

      case ViewAs.region:
        imageToDisplay = _imageDilated;
        return buildInteractiveImageViewer(
          drawRectanglesOnImage(imageToDisplay!),
          widget.transformationController,
        );

      case ViewAs.artifacts:
      case ViewAs.characters:
        return widgetForDisplayingArtifacts(
          widget.transformationController,
        );
    }
  }

  Widget widgetForDisplayingArtifacts(
    final TransformationController transformationController,
  ) {
    return CustomInteractiveViewer(
      transformationController: transformationController,
      child: DisplayBandsAndArtifacts(
        textify: widget.textify,
        viewAs: _viewAs,
        showRegions: _showRegions,
        showHistogram: _showHistograms,
      ),
    );
  }

  void updateImages() {
    debouncer.run(() async {
      if (widget.imageSource == null) {
        if (mounted) {
          setState(() {
            _isReady = true;
            _regions = [];
            _regionsHistograms = [];
            _imageBW = null;
            _imageDilated = null;
          });
        }
        return;
      }

      //
      // Task 1 - Convert to B&W (lightweight, OK on main isolate)
      //
      final ui.Image imageBW = await imageToBlackOnWhite(widget.imageSource!);

      //
      // Task 2-5 - Heavy processing on background isolate
      //
      final StepProcessingResult result =
          await processImageForStepsWithBackgroundIsolate(
        image: imageBW,
        kernelSize: widget.kernelSizeDilate,
      );

      //
      // Convert dilated matrix back to image for display
      //
      final imageDilated = await imageFromMatrix(result.dilatedImage);

      _regions = result.regions;
      _regionsHistograms = result.regionHistograms;
      _imageBW = imageBW;
      _imageDilated = imageDilated;

      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    });
  }

  ui.Image drawRectanglesOnImage(
    ui.Image image,
  ) {
    // Draw rectangles found in regions over the image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the original image first
    canvas.drawImage(image, Offset.zero, Paint());

    // Draw rectangles over the image
    final paintRed = Paint()
      ..color = Colors.red.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintGreen = Paint()
      ..color = Colors.green.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < _regions.length; i++) {
      final IntRect region = _regions[i];
      if (_showRegions) {
        canvas.drawRect(
          intRectToRectDouble(region),
          (i % 2) == 0 ? paintRed : paintGreen,
        );
      }

      // Paint the histogram in the rect space
      if (_showHistograms) {
        final histogramForThisRect = _regionsHistograms[i];
        if (histogramForThisRect.isNotEmpty) {
          final histogramPaint = Paint()
            ..color = Colors.blue.withAlpha(200)
            ..style = PaintingStyle.fill;

          final double barWidth = region.width / histogramForThisRect.length;
          final double maxValue = histogramForThisRect.reduce(max).toDouble();

          for (int j = 0; j < histogramForThisRect.length; j++) {
            if (maxValue > 0) {
              final int barHeight = histogramForThisRect[j];

              final double x = region.left + (j * barWidth);
              final double top = region.bottom - (barHeight * 2);
              for (double y = top; y < region.bottom; y += 2) {
                canvas.drawRect(
                  Rect.fromLTWH(x, y, barWidth, 1),
                  histogramPaint,
                );
              }
            }
          }
        }
      }
    }

    // Convert to an image
    final ui.Picture picture = recorder.endRecording();
    return picture.toImageSync(
      image.width,
      image.height,
    );
  }
}
