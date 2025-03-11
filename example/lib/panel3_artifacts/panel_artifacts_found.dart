import 'package:flutter/material.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/panel1_source/panel_content.dart';
import 'package:textify_dashboard/panel3_artifacts/display_bands_and_artifacts.dart';
import 'package:textify_dashboard/widgets/display_artifact.dart';
import 'package:textify_dashboard/widgets/gap.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

Widget panelArtifactFound({
  required final Textify textify,
  required final ViewAs viewAs,
  required final Function(ViewAs) onChangeView,
  required final TransformationController transformationController,
}) {
  return PanelContent(
    top: _buildActionButtons(
      viewAs,
      onChangeView,
      false,
      transformationController,
    ),
    center: CustomInteractiveViewer(
      transformationController: transformationController,
      child: DisplayBandsAndArtifacts(
        textify: textify,
        viewAs: viewAs,
      ),
    ),
  );
}

Widget _buildActionButtons(
  final ViewAs viewAs,
  final Function(ViewAs) onViewAsChanged,
  final bool cleanUpArtifacts,
  final TransformationController transformationController,
) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      OutlinedButton(
        onPressed: () {
          transformationController.value =
              transformationController.value.scaled(1 / 1.5);
        },
        child: const Text('Zoom -'),
      ),
      gap(),
      OutlinedButton(
        onPressed: () {
          transformationController.value =
              transformationController.value.scaled(1.5);
        },
        child: const Text('Zoom +'),
      ),
      gap(),
      OutlinedButton(
        onPressed: () {
          transformationController.value = Matrix4.identity();
        },
        child: const Text('Center'),
      ),
      gap(),
      DropdownButton<String>(
        value: viewAs == ViewAs.original
            ? 'Original'
            : viewAs == ViewAs.matrix
                ? 'Normalized'
                : 'Histogram',
        items: const [
          DropdownMenuItem(value: 'Original', child: Text('Original')),
          DropdownMenuItem(value: 'Normalized', child: Text('Normalized')),
          DropdownMenuItem(value: 'Histogram', child: Text('Histogram')),
        ],
        onChanged: (value) {
          if (value == 'Original') {
            onViewAsChanged(ViewAs.original);
          } else if (value == 'Normalized') {
            onViewAsChanged(ViewAs.matrix);
          } else if (value == 'Histogram') {
            onViewAsChanged(ViewAs.histogram);
          }
        },
      ),
    ],
  );
}
