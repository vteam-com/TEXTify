// ignore_for_file: unnecessary_this

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:textify/textify.dart';

/// The entry point of the application. Runs the [MainApp] widget.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load your image
  final ui.Image uiImage = await Textify.loadImageFromAssets(
    'assets/samples/the-quick-brown-fox.png',
  );

  // instantiate Textify once
  Textify textify = await Textify().init();

  // Optionally apply English dictionary word correction
  textify.applyDictionary = true;

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
