import 'dart:math';

import 'package:flutter/material.dart';
import 'package:textify/band.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/widgets/display_artifact.dart';

const int offsetX = 00;
const int offsetY = 14;

class ShowFindings extends StatelessWidget {
  const ShowFindings({
    super.key,
    required this.textify,
    required this.applyPacking,
  });

  final bool applyPacking;
  final Textify textify;

  @override
  Widget build(BuildContext context) {
    double maxWidth = 0;
    double maxHeight = 0;
    for (final Band band in textify.bands) {
      if (band.artifacts.isNotEmpty) {
        maxWidth = max(maxWidth, band.rectangle.right + offsetX);
        maxHeight = max(maxHeight, band.rectangle.bottom + offsetY);
      }
    }

    return SizedBox(
      width: maxWidth,
      height: maxHeight + 100,
      child: CustomPaint(
        key: Key(textify.processEnd.toString()),
        painter: DisplayArtifacts(
          textify: textify,
          applyPacking: applyPacking,
        ),
        size: Size(maxWidth, maxHeight),
      ),
    );
  }
}
