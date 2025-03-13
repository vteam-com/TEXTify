import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:textify/matrix.dart';
import 'package:textify_dashboard/panel1_source/panel_content.dart';
import 'package:textify_dashboard/panel2_steps/panel_steps_toolbar.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

class PanelSteps extends StatefulWidget {
  const PanelSteps({
    super.key,
    required this.imageSource,
    required this.regions,
    required this.kernelSizeDilate,
    required this.displayChoicesChanged,
    required this.onReset,
    required this.transformationController,
  });
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
  late ViewImageSteps _step2viewImageAs;
  ui.Image? _imageGrayScale;
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
    _step2viewImageAs = ViewImageSteps.grayScale;
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
    if (widget.imageSource == null) {
      return Center(child: Text('No input image'));
    }

    if (_isReady == false) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    switch (_step2viewImageAs) {
      case ViewImageSteps.grayScale:
        imageToDisplay = _imageGrayScale;

      case ViewImageSteps.blackAndWhite:
        imageToDisplay = _imageBW;

      case ViewImageSteps.region:
        imageToDisplay = _imageDilated;
    }

    return PanelContent(
      top: PanelStepsToolbar(
        viewAsStep: _step2viewImageAs,
        onViewChanged: (ViewImageSteps view) {
          setState(() {
            _step2viewImageAs = view;
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
      center: buildInteractiveImageViewer(
        drawRectanglesOnImage(imageToDisplay!),
        widget.transformationController,
      ),
    );
  }

  void updateImages() {
    setState(() {
      _isReady = false;
      imageToGrayScale(widget.imageSource!).then((imageGrayScale) {
        imageToBlackOnWhite(imageGrayScale).then((final ui.Image imageBW) {
          Matrix.fromImage(imageBW).then((final Matrix binaryImage) {
            dilate(
              inputImage: imageBW,
              kernelSize: widget.kernelSizeDilate,
            ).then((final ui.Image imageDilated) {
              setState(() {
                _isReady = true;
                _imageGrayScale = imageGrayScale;
                _regions = findRegions(
                  binaryImage,
                  kernelSize: widget.kernelSizeDilate,
                );
                _regionsHistograms =
                    getHistogramOfRegions(binaryImage, _regions);
                _imageBW = imageBW;
                _imageDilated = imageDilated;
              });
            });
          });
        });
      });
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
            ..color = Colors.blue.withAlpha(150)
            ..style = PaintingStyle.fill;

          final double barWidth = rect.width / histogramForThisRect.length;
          final double maxValue = histogramForThisRect.reduce(max).toDouble();

          for (int j = 0; j < histogramForThisRect.length; j++) {
            if (maxValue > 0) {
              final double barHeight =
                  (histogramForThisRect[j] / maxValue) * rect.height;
              final double x = rect.left + (j * barWidth);
              final double y = rect.bottom - barHeight;

              canvas.drawRect(
                Rect.fromLTWH(x, y, barWidth, barHeight),
                histogramPaint,
              );
            }
          }

          final paintYellowOverlay = Paint()
            ..color = Colors.yellow.withAlpha(100)
            ..style = PaintingStyle.fill;

          // Find continuous non-zero regions in histogram
          int startIndex = -1;
          for (int k = 0; k < histogramForThisRect.length; k++) {
            if (startIndex == -1 && histogramForThisRect[k] > 0) {
              startIndex = k;
            } else if (startIndex != -1 && histogramForThisRect[k] == 0) {
              // Draw rectangle for non-zero region
              final double x = rect.left + (startIndex * barWidth);
              final double width = (k - startIndex) * barWidth;
              canvas.drawRect(
                Rect.fromLTWH(x, rect.top, width, rect.height),
                paintYellowOverlay,
              );
              startIndex = -1;
            }
          }
          // Handle case where non-zero region extends to the end
          if (startIndex != -1) {
            final double x = rect.left + (startIndex * barWidth);
            final double width =
                (histogramForThisRect.length - startIndex) * barWidth;
            canvas.drawRect(
              Rect.fromLTWH(x, rect.top, width, rect.height),
              paintYellowOverlay,
            );
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
