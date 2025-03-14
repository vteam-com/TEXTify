import 'dart:math';

import 'package:flutter/material.dart';
import 'package:textify/band.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/widgets/display_artifact.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

const int offsetX = 00;
const int offsetY = 14;

class DisplayBandsAndArtifacts extends StatelessWidget {
  const DisplayBandsAndArtifacts({
    super.key,
    required this.textify,
    required this.viewAs,
    required this.showRegions,
    required this.showHistogram,
  });

  final Textify textify;
  final ViewAs viewAs;
  final bool showRegions;
  final bool showHistogram;

  @override
  Widget build(BuildContext context) {
    double maxWidth = 0;
    double maxHeight = 0;

    for (final Band band in textify.bands.list) {
      if (band.artifacts.isNotEmpty) {
        late Rect rect;
        if (viewAs == ViewAs.characters) {
          rect = band.rectangleAdjusted;
        } else {
          rect = band.rectangleOriginal;
        }
        maxWidth = max(maxWidth, rect.right + offsetX);
        maxHeight = max(maxHeight, rect.bottom + offsetY);
      }
    }

    return SizedBox(
      width: maxWidth,
      height: maxHeight + 100,
      child: CustomPaint(
        key: Key(textify.processEnd.toString()),
        painter: PaintArtifacts(
          textify: textify,
          viewAs: viewAs,
          showRegions: showRegions,
          showHistogram: showHistogram,
        ),
        size: Size(maxWidth, maxHeight),
      ),
    );
  }
}
