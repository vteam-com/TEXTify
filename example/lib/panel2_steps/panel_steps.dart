import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:textify_dashboard/panel1_source/panel_content.dart';
import 'package:textify_dashboard/panel2_steps/panel_steps_toolbar.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

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
    top: PanelStepsToolbar(
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
