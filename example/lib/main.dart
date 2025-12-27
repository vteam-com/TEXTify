// ignore_for_file: unnecessary_this

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:textify/models/textify_config.dart';
import 'package:textify/textify.dart';

/// The entry point of the application. Runs the [MainApp] widget.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load your image
  final ui.Image uiImage = await Textify.loadImageFromAssets(
    'assets/samples/the-quick-brown-fox.png',
  );

  // instantiate Textify once with dictionary correction enabled
  Textify textify = await Textify(
    config: const TextifyConfig(applyDictionaryCorrection: true),
  ).init();

  // extract text from the image
  final String extractedText = await textify.getTextFromImage(image: uiImage);

  runApp(
    MaterialApp(
      title: 'TEXTify example',
      home: Container(
        color: Colors.white,
        child: Text(
          extractedText, // <<< display the text here
          style: TextStyle(
            color: Colors.black,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ),
  );
}
