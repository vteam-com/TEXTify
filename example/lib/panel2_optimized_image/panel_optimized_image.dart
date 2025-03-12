import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:textify_dashboard/panel1_source/panel_content.dart';
import 'package:textify_dashboard/widgets/gap.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

class ThresholdControlWidget extends StatelessWidget {
  const ThresholdControlWidget({
    super.key,
    required this.erodeFirst,
    required this.kernelSizeErode,
    required this.kernelSizeDilate,
    required this.onChanged,
    required this.onReset,
  });
  final bool erodeFirst;
  final int kernelSizeErode;
  final int kernelSizeDilate;
  final Function(
    bool,
    int,
    int,
  ) onChanged;
  final Function onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 40,
      children: [
        _buildErodeButtons(),
        Row(
          children: [
            Checkbox(
              value: erodeFirst,
              onChanged: (value) {
                onChanged(
                  value ?? false,
                  kernelSizeErode,
                  kernelSizeDilate,
                );
              },
            ),
            Text('Erode First'),
          ],
        ),
        _buildDilateButtons(),
        OutlinedButton(
          onPressed: () {
            onReset();
          },
          child: Text('Reset'),
        ),
      ],
    );
  }

  Widget _buildErodeButtons() {
    return Row(
      children: [
        _buildButton('-', () {
          if (kernelSizeErode > 0) {
            onChanged(
              erodeFirst,
              kernelSizeErode - 1,
              kernelSizeDilate,
            );
          }
        }),
        gap(),
        Text('Erode: $kernelSizeErode'),
        gap(),
        _buildButton('+', () {
          onChanged(
            erodeFirst,
            kernelSizeErode + 1,
            kernelSizeDilate,
          );
        }),
      ],
    );
  }

  Widget _buildDilateButtons() {
    return Row(
      children: [
        _buildButton('-', () {
          if (kernelSizeDilate > 0) {
            onChanged(
              erodeFirst,
              kernelSizeErode,
              kernelSizeDilate - 1,
            );
          }
        }),
        gap(),
        Text('Dilate: $kernelSizeDilate'),
        gap(),
        _buildButton('+', () {
          onChanged(
            erodeFirst,
            kernelSizeErode,
            kernelSizeDilate + 1,
          );
        }),
      ],
    );
  }

  // New helper method to create buttons
  Widget _buildButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

Widget panelOptimizedImage({
  required final ui.Image? imageBlackOnWhite,
  required final List<Rect> regions,
  required final bool erodeFirst,
  required final int kernelSizeErode,
  required final int kernelSizeDilate,
  required final Function(bool, int, int) displayChoicesChanged,
  required final Function onReset,
  required final TransformationController transformationController,
}) {
  ui.Image? imageToDisplay;

  if (imageBlackOnWhite != null) {
    // Draw rectangles found in regions over the image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the original image first
    canvas.drawImage(imageBlackOnWhite, Offset.zero, Paint());

    // Draw rectangles over the image
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final rect in regions) {
      canvas.drawRect(rect, paint);
    }

    // Convert to an image
    final ui.Picture picture = recorder.endRecording();
    imageToDisplay = picture.toImageSync(
      imageBlackOnWhite.width,
      imageBlackOnWhite.height,
    );
  }

  return PanelContent(
    top: ThresholdControlWidget(
      erodeFirst: erodeFirst,
      kernelSizeErode: kernelSizeErode,
      kernelSizeDilate: kernelSizeDilate,
      onChanged: displayChoicesChanged,
      onReset: onReset,
    ),
    center: imageToDisplay == null
        ? null
        : buildInteractiveImageViewer(
            imageToDisplay,
            transformationController,
          ),
  );
}
