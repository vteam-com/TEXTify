import 'dart:math';

import 'package:flutter/material.dart';
import 'package:textify/band.dart';
import 'package:textify/int_rect.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/widgets/display_artifact.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';
import 'package:textify_dashboard/widgets/paint_artifact.dart';

const int offsetX = 00;
const int offsetY = 14;

class DisplayBandsAndArtifacts extends StatefulWidget {
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
  State<DisplayBandsAndArtifacts> createState() =>
      _DisplayBandsAndArtifactsState();
}

class _DisplayBandsAndArtifactsState extends State<DisplayBandsAndArtifacts> {
  void _handleTapDown(final TapDownDetails details) {
    final IntOffset localPosition = IntOffset(
      details.localPosition.dx.toInt(),
      details.localPosition.dy.toInt(),
    );

    for (final band in widget.textify.bands.list) {
      for (final artifact in band.artifacts) {
        final IntRect rect = widget.viewAs == ViewAs.characters
            ? artifact.rectAdjusted
            : artifact.rectFound;

        if (rect.containsOffset(localPosition)) {
          _showArtifactDetails(artifact);
          break;
        }
      }
    }
  }

  void _showArtifactDetails(Artifact artifact) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Artifact ${artifact.matchingCharacterDescription}'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 40,
              children: [
                DisplayArtifact(
                  artifact: artifact,
                ),
                Column(
                  spacing: 10,
                  children: [
                    // Artifact details
                    Text(
                      '"${artifact.matchingCharacter}"',
                      style: TextStyle(fontSize: 20),
                    ),
                    Text(
                      'Score: ${(artifact.matchingScore * 100).toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 20),
                    ),
                    Text(
                      'Position: ${artifact.locationFound.x}, ${artifact.locationFound.y}',
                    ),
                    Text('Size: ${artifact.cols} × ${artifact.rows}'),
                    if (artifact.needsInspection)
                      const Text(
                        'Needs Inspection',
                        style: TextStyle(color: Colors.red),
                      ),
                    if (artifact.wasPartOfSplit)
                      const Text(
                        'Was Split',
                        style: TextStyle(color: Colors.green),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int maxWidth = 0;
    int maxHeight = 0;

    for (final Band band in widget.textify.bands.list) {
      if (band.artifacts.isNotEmpty) {
        late IntRect rect;
        if (widget.viewAs == ViewAs.characters) {
          rect = band.rectangleAdjusted;
        } else {
          rect = band.rectangleOriginal;
        }
        maxWidth = max(maxWidth, rect.right + offsetX);
        maxHeight = max(maxHeight, rect.bottom + offsetY);
      }
    }

    return SizedBox(
      width: maxWidth.toDouble(),
      height: maxHeight + 100,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: CustomPaint(
          key: Key(widget.textify.processEnd.toString()),
          painter: PaintArtifacts(
            textify: widget.textify,
            viewAs: widget.viewAs,
            showRegions: widget.showRegions,
            showHistogram: widget.showHistogram,
          ),
          size: Size(maxWidth.toDouble(), maxHeight.toDouble()),
        ),
      ),
    );
  }
}
