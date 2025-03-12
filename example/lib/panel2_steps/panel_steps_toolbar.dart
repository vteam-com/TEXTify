import 'package:flutter/material.dart';

class PanelStepsToolbar extends StatelessWidget {
  const PanelStepsToolbar({
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
      spacing: 10,
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
        Text('Erode: $kernelSizeErode'),
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
      spacing: 10,
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
        Text('Dilate: $kernelSizeDilate'),
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
