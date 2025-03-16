import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:textify/artifact.dart';
import 'package:textify/character_definition.dart';
import 'package:textify/matrix.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/generate_samples/generate_image.dart';
import 'package:textify_dashboard/generate_samples/textify_generated_image.dart';
import 'package:textify_dashboard/panel1_source/image_source_generated.dart';
import 'package:textify_dashboard/widgets/gap.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';

class GenerateImagesForUnitTestsScreen extends StatefulWidget {
  const GenerateImagesForUnitTestsScreen({
    super.key,
    required this.textify,
  });
  final Textify textify;

  @override
  ContentState createState() => ContentState();
}

class ProcessedCharacter {
  ProcessedCharacter(this.character);
  String character = '';
  List<Artifact> artifacts = [];
  List<String> description = [];
  List<String> problems = [];
}

class ContentState extends State<GenerateImagesForUnitTestsScreen> {
  final bool _completed = false;
  bool _cancel = false;
  late final Textify textify;
  Map<String, ProcessedCharacter> processedCharacters = {};
  String displayDetailsForCharacter = '';
  String displayDetailsForCharacterProblems = '';
  int numberOfImageToGenerate = 10;
  List<Widget> imagesWithTextGenerated = [];

  @override
  void initState() {
    super.initState();

    _generateImages();
  }

  Future<void> _generateImages() async {
    this.textify = await Textify().init();
    this.textify.excludeLongLines = false;

    for (int i = 0; i < numberOfImageToGenerate; i++) {
      final text = '$i The Quick Brown Fox\n123.45';
      final int fontSize = 10 + (i * 2);
      final String font = 'Arial';
      final int imageWidth = 400;
      final int imageHeight = 200;

      final image = await generateImageDrawText(
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        text: text,
        fontFamily: font,
        fontSize: fontSize,
      );

      if (_cancel) {
        break;
      }
      imagesWithTextGenerated.add(
        containerImageAndText(
          '($i) $imageWidth X $imageHeight  "$font", $fontSize',
          image,
          text,
        ),
      );
    }

    setState(() {
      // update
    });
  }

  Widget containerImageAndText(
    final String title,
    final ui.Image image,
    final String expectedText,
  ) {
    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 15,
            spreadRadius: 5,
            offset: Offset(5, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 500, child: ImageViewer(image: image)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Text(title),
                  Text(expectedText),
                ],
              ),
            ),
          ),
          Container(
            width: 200,
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: TextifyingImage(
              textify: widget.textify,
              image: image,
              expectedText: expectedText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Test Images')),
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          spacing: 10,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_completed ? 'Completed' : 'Processing'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: imagesWithTextGenerated.length,
                itemBuilder: (context, index) {
                  return imagesWithTextGenerated[index];
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  child: Text(_completed ? 'Close' : 'Cancel'),
                  onPressed: () {
                    if (_completed) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        _cancel = true;
                      });
                    }
                  },
                ),
                gap(),
                if (_completed)
                  OutlinedButton(
                    child: Text('Copy as "matrices.json"'),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: textify.characterDefinitions.toJsonString(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Updates the character definition for a single character and a single font.
  ///
  /// This function generates an image for the given character and font, processes
  /// the image to find artifacts, and updates the character definition accordingly.
  ///
  /// Args:
  ///   char: The character to be processed.
  ///   fontName: The name of the font to be used.
  ///   processedCharacter: An object to store the processed character information.
  ///
  /// Returns:
  ///   A list of dynamic problems encountered during the processing.
  Future<void> updateSingleCharSingleFont(
    String char,
    String fontName,
    ProcessedCharacter processedCharacter,
  ) async {
    // Generate an image for the character and font
    final ui.Image newImageSource = await generateImageDrawText(
      imageWidth: 40 * 6,
      imageHeight: 60,
      // Surround the character with 'A' and 'W' for better detection
      text: 'A $char W',
      fontFamily: fontName,
      fontSize: imageSettings.fontSize.toInt(),
    );

    // Apply image processing pipeline
    final ui.Image imageOptimized = await imageToBlackOnWhite(newImageSource);
    final Matrix imageAsMatrix = await Matrix.fromImage(imageOptimized);

    // Find artifacts from the binary image
    textify.identifyArtifactsAndBandsInBinaryImage(imageAsMatrix);

    // If there is only one band (expected for a single character)
    if (textify.bands.length == 1) {
      final List<Artifact> artifactsInTheFirstBand =
          textify.bands.list.first.artifacts;

      // Filter out artifacts with empty matrices (spaces)
      final artifactsInTheFirstBandNoSpaces = artifactsInTheFirstBand
          .where((Artifact artifact) => artifact.matrix.isNotEmpty)
          .toList();

      // If there are exactly three artifacts (expected for a single character)
      if (artifactsInTheFirstBandNoSpaces.length == 3) {
        final targetArtifact = artifactsInTheFirstBandNoSpaces[
            1]; // The middle artifact is the target

        // Create a normalized matrix for the character definition
        final Matrix matrix = targetArtifact.matrix.createNormalizeMatrix(
          CharacterDefinition.templateWidth,
          CharacterDefinition.templateHeight,
        );

        // Update the character definition with the new matrix
        final wasNewDefinition =
            textify.characterDefinitions.upsertTemplate(fontName, char, matrix);

        // If the matrix is empty, add a problem message
        if (matrix.isEmpty) {
          processedCharacter.problems.add('***** NO Content found');
        } else {
          // Add a description with the font name, whether it's a new definition, and the matrix
          processedCharacter.description
              .add('$fontName  IsNew:$wasNewDefinition    $matrix');
        }

        // Add the target artifact to the processed character
        processedCharacter.artifacts.add(targetArtifact);
      } else {
        // If the number of artifacts is not 3, add a problem message
        processedCharacter.problems.add('Not found');

        // Merge all artifacts into the first one
        if (artifactsInTheFirstBandNoSpaces.isNotEmpty) {
          final firstArtifact = artifactsInTheFirstBandNoSpaces[0];
          for (int i = 1; i < artifactsInTheFirstBandNoSpaces.length; i++) {
            firstArtifact.mergeArtifact(artifactsInTheFirstBandNoSpaces[i]);
          }
          processedCharacter.artifacts
              .add(firstArtifact); // Add the merged artifact
        } else {
          processedCharacter.problems.add(
            'No artifacts found',
          ); // Add a problem message if no artifacts were found
        }
      }
    }
  }
}
