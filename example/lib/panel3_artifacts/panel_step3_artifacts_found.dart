import 'package:flutter/material.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/panel1_source/panel_step_content.dart';
import 'package:textify_dashboard/panel3_artifacts/display_bands_and_artifacts.dart';
import 'package:textify_dashboard/widgets/display_artifact.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

Widget panelStep3ArtifactsFound({
  required final Textify textify,
  required final ViewAs viewAs,
  required final Function(ViewAs) onChangeView,
  required final TransformationController transformationController,
}) {
  return PanelStepContent(
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
    mainAxisAlignment: MainAxisAlignment.start,
    spacing: 10,
    children: [
      OutlinedButton(
        onPressed: () {
          transformationController.value =
              transformationController.value.scaled(1 / 1.5);
        },
        child: const Text('Zoom -'),
      ),
      OutlinedButton(
        onPressed: () {
          transformationController.value =
              transformationController.value.scaled(1.5);
        },
        child: const Text('Zoom +'),
      ),
      DropdownButton<ViewAs>(
        value: viewAs,
        items: const [
          DropdownMenuItem(
            value: ViewAs.original,
            child: Text('Original'),
          ),
          DropdownMenuItem(
            value: ViewAs.originalHistogram,
            child: Text('Original Histogram'),
          ),
          DropdownMenuItem(
            value: ViewAs.matrix,
            child: Text('Normalized'),
          ),
          DropdownMenuItem(
            value: ViewAs.matrixHistogram,
            child: Text('Normalized Histogram'),
          ),
        ],
        onChanged: (ViewAs? value) {
          onViewAsChanged(value!);
        },
      ),
    ],
  );
}
