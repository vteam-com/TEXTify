import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:textify/artifact.dart';
import 'package:textify/character_definition.dart';
import 'package:textify/textify.dart';
import 'package:textify/utilities.dart';
import 'package:textify_dashboard/generate_samples/generate_image.dart';
import 'package:textify_dashboard/panel1_source/image_source_generated.dart';
import 'package:textify_dashboard/widgets/gap.dart';

class CharacterGenerationScreen extends StatelessWidget {
  const CharacterGenerationScreen({
    super.key,
    required this.onComplete,
    required this.availableFonts,
  });
  final Function onComplete;
  final List<String> availableFonts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Character Generation')),
      body: CharacterGenerationBody(
        availableFonts: availableFonts,
        onComplete: onComplete,
      ),
    );
  }
}

class CharacterGenerationBody extends StatefulWidget {
  const CharacterGenerationBody({
    super.key,
    required this.onComplete,
    required this.availableFonts,
  });
  final Function onComplete;
  final List<String> availableFonts;

  @override
  CharacterGenerationBodyState createState() => CharacterGenerationBodyState();
}

class ProcessedCharacter {
  ProcessedCharacter(this.character);
  String character = '';
  List<Artifact> artifacts = [];
  List<String> description = [];
  List<String> problems = [];
}

class CharacterGenerationBodyState extends State<CharacterGenerationBody> {
  String _currentChar = '';
  bool _completed = false;
  bool _cancel = false;
  late final Textify textify;
  List _supportedCharacters = [];
  Map<String, ProcessedCharacter> processedCharacters = {};
  String displayDetailsForCharacter = '';
  String displayDetailsForCharacterProblems = '';

  @override
  void initState() {
    super.initState();

    _generateCharacters();
  }

  Future<void> _generateCharacters() async {
    this.textify = await Textify().init();
    // we only want to detect a single character, skip Space detections

    this.textify.excludeLongLines = false;
    _supportedCharacters =
        this.textify.characterDefinitions.supportedCharacters;

    for (String char in _supportedCharacters) {
      if (char == ' ') {
        processedCharacters[char] = (ProcessedCharacter(char));
        continue;
      }
      if (_cancel) {
        break;
      }
      setState(() {
        _currentChar = char;
      });
      await updateEachCharactersForEveryFonts(char);
    }
    setState(() {
      _completed = true;
    });
    widget.onComplete(); // Call the completion function when done
  }

  Color _getColorForCharacterBorder(final String char) {
    ProcessedCharacter? pc = processedCharacters[char];
    if (pc == null) {
      return Colors.grey;
    }
    return pc.problems.isEmpty ? Colors.green : Colors.orange;
  }

  Widget _buildProgress() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(_completed ? 'Completed' : 'Processing'),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: _supportedCharacters.map((char) {
            // Check if the character is the current character
            final bool isCurrentChar =
                char == _currentChar && _completed == false;
            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _getColorForCharacterBorder(char)),
              ),
              onPressed: () {
                setState(() {
                  displayDetailsForCharacter = char;
                  ProcessedCharacter? pc = processedCharacters[char];
                  displayDetailsForCharacterProblems =
                      pc!.description.join('\n');
                });
              },
              child: Text(
                char,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: ui.FontWeight.bold,
                  fontSize: 20, // Larger font for current char
                  color: isCurrentChar && _completed == false
                      ? Colors.blue
                      : Colors.white, // Blue for current char
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDetailsOfCharacter(final String char) {
    final ProcessedCharacter? pc = processedCharacters[char];

    return Column(
      children: [
        Text(
          displayDetailsForCharacter,
          style: const TextStyle(fontSize: 100),
        ),
        Text(displayDetailsForCharacterProblems),
        if (pc != null)
          Expanded(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: pc.artifacts.map((artifact) {
                  return DecoratedBox(
                    decoration:
                        BoxDecoration(border: Border.all(color: Colors.grey)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 5,
                          color: pc.problems.isEmpty
                              ? Colors.green
                              : Colors.orange,
                        ),
                        artifact.gridToString(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          Center(child: _buildProgress()),
          Expanded(
            child: _buildDetailsOfCharacter(displayDetailsForCharacter),
          ),
          gap(),
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
    );
  }

  Future<void> updateEachCharactersForEveryFonts(String char) async {
    final processedCharacter = ProcessedCharacter(char);

    for (final fontName in widget.availableFonts) {
      await updateSingleCharSingleFont(char, fontName, processedCharacter);
      setState(() {
        // update
      });
    }
    processedCharacters[char] = processedCharacter;
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
    final Artifact imageAsMatrix = await Artifact.fromImage(imageOptimized);

    // Find artifacts from the binary image
    textify.extractBandsAndArtifacts(imageAsMatrix);

    // If there is only one band (expected for a single character)
    if (textify.bands.length == 1) {
      final List<Artifact> artifactsInTheFirstBand =
          textify.bands.list.first.artifacts;

      // Filter out artifacts with empty matrices (spaces)
      final artifactsInTheFirstBandNoSpaces = artifactsInTheFirstBand
          .where((Artifact artifact) => artifact.isNotEmpty)
          .toList();

      // If there are exactly three artifacts (expected for a single character)
      if (artifactsInTheFirstBandNoSpaces.length == 3) {
        final targetArtifact = artifactsInTheFirstBandNoSpaces[
            1]; // The middle artifact is the target

        // Create a normalized matrix for the character definition
        final Artifact matrix = targetArtifact.createNormalizeMatrix(
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
