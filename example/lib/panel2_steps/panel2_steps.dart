import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:textify/matrix.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/generate_samples/generate_image.dart';
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
    required this.kernelSizeDilate,
    required this.displayChoicesChanged,
    required this.onReset,
    required this.transformationController,
  });
  final Textify textify;
  final ui.Image? imageSource;
  final List<Rect> regions;
  final int kernelSizeDilate;
  final Function(int) displayChoicesChanged;
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
  List<Rect> _regions = [];
  List<List<int>> _regionsHistograms = [];
  bool _showRegions = false;
  bool _showHistograms = false;

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
        // Region
        showRegions: _showRegions,
        onShowRegionsChanged: (value) {
          setState(() {
            _showRegions = value;
          });
        },
        showHistograms: _showHistograms,
        onShowHistogramsChanged: (value) {
          setState(() {
            _showHistograms = value;
          });
        },
        // dilate
        kernelSizeDilate: widget.kernelSizeDilate,
        onDelateChanged: widget.displayChoicesChanged,

        onReset: widget.onReset,
      ),
      center: centerContent(),
      bottom: buildPanelHeader(
        '${widget.textify.count} Artifacts',
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
        child: CircularProgressIndicator(),
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
    setState(() {
      _isReady = false;
      if (widget.imageSource != null) {
        imageToBlackOnWhite(widget.imageSource!).then((final ui.Image imageBW) {
          Matrix.fromImage(imageBW).then((final Matrix binaryImage) {
            final Matrix dilatedMatrix = dilateMatrix(
              matrixImage: binaryImage,
              kernelSize: widget.kernelSizeDilate,
            );

            imageFromMatrix(dilatedMatrix).then((imageDilated) {
              setState(() {
                _isReady = true;
                _regions = findRegions(dilatedMatrixImage: dilatedMatrix);
                _regionsHistograms =
                    getHistogramOfRegions(binaryImage, _regions);
                _imageBW = imageBW;
                _imageDilated = imageDilated;
              });
            });
          });
        });
      }
    });
  }

  List<List<int>> getHistogramOfRegions(
    final Matrix binaryImage,
    List<Rect> regions,
  ) {
    List<List<int>> regionsHistograms = [];

    for (final ui.Rect region in regions) {
      regionsHistograms.add(getHistogramOfRegion(binaryImage, region));
    }
    return regionsHistograms;
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
    final paint = Paint()
      ..color = Colors.red.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < _regions.length; i++) {
      final rect = _regions[i];
      if (_showRegions) {
        canvas.drawRect(rect, paint);
      }

      // Paint the histogram in the rect space
      if (_showHistograms) {
        final histogramForThisRect = _regionsHistograms[i];
        if (histogramForThisRect.isNotEmpty) {
          final histogramPaint = Paint()
            ..color = Colors.blue.withAlpha(200)
            ..style = PaintingStyle.fill;

          final double barWidth = rect.width / histogramForThisRect.length;
          final double maxValue = histogramForThisRect.reduce(max).toDouble();

          for (int j = 0; j < histogramForThisRect.length; j++) {
            if (maxValue > 0) {
              final int barHeight = histogramForThisRect[j];

              final double x = rect.left + (j * barWidth);
              final double top = rect.bottom - (barHeight * 2);
              for (double y = top; y < rect.bottom; y += 2) {
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
