import 'package:flutter/material.dart';

Widget panelStep4toolbar(
  final bool applyDictionary,
  Function(bool) onChanged,
) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      SizedBox(
        width: 220,
        child: CheckboxListTile(
          title: const Text('Apply Dictionary'),
          value: applyDictionary,
          onChanged: (bool? value) {
            onChanged(value!);
          },
        ),
      ),
    ],
  );
}
