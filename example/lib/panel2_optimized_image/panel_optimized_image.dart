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
    required this.grayscaleLevel,
    required this.onChanged,
    required this.onReset,
  });
  final bool erodeFirst;
  final int kernelSizeErode;
  final int kernelSizeDilate;
  final int grayscaleLevel;
  final Function(bool, int, int, int) onChanged;
  final Function onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 40,
      children: [
        _buildGrayscaleButtons(),
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
                  grayscaleLevel,
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

  Widget _buildGrayscaleButtons() {
    return Row(
      children: [
        _buildButton('-', () {
          if (grayscaleLevel > 0) {
            onChanged(
              erodeFirst,
              kernelSizeErode,
              kernelSizeDilate,
              grayscaleLevel - 1,
            );
          }
        }),
        gap(),
        Text('GrayScale: $grayscaleLevel'), // Display current grayscale level
        gap(),
        _buildButton('+', () {
          if (grayscaleLevel < 255) {
            onChanged(
              erodeFirst,
              kernelSizeErode,
              kernelSizeDilate,
              grayscaleLevel + 1,
            );
          }
        }),
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
              grayscaleLevel,
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
            grayscaleLevel,
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
              grayscaleLevel,
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
            grayscaleLevel,
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
  required final bool erodeFirst,
  required final int kernelSizeErode,
  required final int kernelSizeDilate,
  required final int grayscaleLevel,
  required final Function(bool, int, int, int) displayChoicesChanged,
  required final Function onReset,
  required final TransformationController transformationController,
}) {
  return PanelContent(
    top: ThresholdControlWidget(
      erodeFirst: erodeFirst,
      kernelSizeErode: kernelSizeErode,
      kernelSizeDilate: kernelSizeDilate,
      grayscaleLevel: grayscaleLevel,
      onChanged: displayChoicesChanged,
      onReset: onReset,
    ),
    center: imageBlackOnWhite == null
        ? null
        : buildInteractiveImageViewer(
            imageBlackOnWhite,
            transformationController,
          ),
  );
}
