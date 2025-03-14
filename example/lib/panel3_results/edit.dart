import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:textify/artifact.dart';
import 'package:textify/character_definitions.dart';
import 'package:textify/matrix.dart';
import 'package:textify/score_match.dart';

import 'package:textify/textify.dart';
import 'package:textify_dashboard/widgets/paint_grid.dart';

class EditScreen extends StatefulWidget {
  const EditScreen({
    super.key,
    required this.textify,
    required this.artifact,
    required this.characterExpected,
    required this.characterFound,
  });
  final Textify textify;
  final Artifact artifact;
  final String characterExpected;
  final String characterFound;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: _buildContent(context),
        ),
      ),
    );
  }

  String attributeOfMatrix(final String title, Matrix matrix) {
    return '$title\n${matrix.cols}x${matrix.rows} E:${widget.artifact.matrix.enclosures} '
        '${captionWithYesNo("VL", matrix.verticalLineLeft)} ${captionWithYesNo("VR", matrix.verticalLineRight)} ${captionWithYesNo("P", matrix.isPunctuation())}';
  }

  String attributeOfCharacterDefinition(
    final String title,
    CharacterDefinition template,
  ) {
    return '$title\n40x60 E:${template.enclosures} '
        '${captionWithYesNo("VL", template.lineLeft)} ${captionWithYesNo("VR", template.lineRight)} ${captionWithYesNo("P", template.isPunctuation)}';
  }

  String captionWithYesNo(final String caption, final bool value) {
    return '$caption:${value ? 'Y' : 'N'}';
  }

  static Widget _buildArtifactGrid(
    final String title,
    final Color headerBackgroundColor,
    final Matrix matrix1,
    final Matrix? matrix2,
    final textForClipboard,
  ) {
    return Container(
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(
            title,
            headerBackgroundColor,
            IconButton(
              icon: Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: textForClipboard));
              },
            ),
          ),
          DisplayMatrix(
            matrix1: matrix1,
            matrix2: matrix2,
            pixelSize: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(final BuildContext context) {
    final List<ScoreMatch> scoreMatches =
        widget.textify.getMatchingScoresOfNormalizedMatrix(widget.artifact);

    final ScoreMatch scoreOfExpectedCharacter = scoreMatches.firstWhere(
      (scoreMatch) => scoreMatch.character == widget.characterExpected,
      orElse: () => ScoreMatch.empty(),
    );

    if (scoreOfExpectedCharacter.isEmpty) {
      // not found
    } else {
      if (scoreMatches.first != scoreOfExpectedCharacter) {
        // We do not have the expected match
        // Move the expected match to the second position of the list
        scoreMatches.remove(scoreOfExpectedCharacter);
        scoreMatches.insert(1, scoreOfExpectedCharacter);
      }
    }
    // Make sure that we don't have redundant trailing entries
    final scoresMatchToDisplay = scoreMatches
        .fold<List<ScoreMatch>>([], (uniqueList, entry) {
          if (uniqueList.length < 2 ||
              !uniqueList.any((e) => e.character == entry.character)) {
            uniqueList.add(entry);
          }
          return uniqueList;
        })
        .take(20)
        .toList();

    final int w = widget.textify.templateWidth;
    final int h = widget.textify.templateHeight;

    final normalized = widget.artifact.matrix.createNormalizeMatrix(w, h);

    List<Widget> widgets = [
      // Artifact Original
      _buildArtifactGrid(
        attributeOfMatrix('Artifact\nFound', widget.artifact.matrix),
        Colors.black,
        widget.artifact.matrix,
        null,
        widget.artifact.toText(forCode: true),
      ),

      // Artifact Adjusted
      _buildArtifactGrid(
        attributeOfMatrix(
          'Artifact\nNormalized',
          normalized,
        ),
        Colors.grey.withAlpha(100),
        normalized,
        null,
        normalized.gridToString(forCode: true),
      ),

      // Expected templates and matches
      ..._buildTemplates(
        scoresMatchToDisplay,
        w,
        h,
        // Artifact found
        normalized,

        // Expected Character
        widget.characterExpected,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
    );
  }

  static Widget _buildHeader(
    final String title,
    final Color headerBackgroundColor,
    final Widget copyButton,
  ) {
    return Container(
      height: 100,
      width: 250,
      color: headerBackgroundColor,
      padding: const EdgeInsets.all(4.0),
      margin: const EdgeInsets.all(4.0),
      child: Stack(
        alignment: AlignmentDirectional.topStart,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Courier',
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: copyButton,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTemplates(
    List<ScoreMatch> scoreMatches,
    final int w,
    final int h,
    final Matrix matrixNormalized,
    // Expected
    final String characterExpected,
  ) {
    List<Widget> widgets = [];

    int index = 0;

    for (final ScoreMatch match in scoreMatches) {
      if (match.score > 0) {
        String title = 'Match ${++index}';
        Color headerColor = index == 1
            ? const Color.fromARGB(255, 169, 61, 2)
            : Colors.red.withAlpha(100);
        if (match.character == characterExpected) {
          title += ' EXPECTED';
          headerColor = Colors.green.withAlpha(100);
        }

        final CharacterDefinition? definition =
            widget.textify.characterDefinitions.getDefinition(match.character);
        if (definition != null) {
          final templateMatrix = definition.matrices[match.matrixIndex];

          title +=
              '\n"${match.character}" [${templateMatrix.font}]\nScore ${(match.score * 100).toStringAsFixed(1)}% ${attributeOfCharacterDefinition('', definition)}';
        }

        final Matrix characterMatrix = widget.textify.characterDefinitions
            .getMatrix(match.character, match.matrixIndex);

        widgets.add(
          Column(
            children: [
              _buildArtifactGrid(
                title,
                headerColor,
                matrixNormalized,
                characterMatrix,
                characterMatrix..gridToString(forCode: true),
              ),
              ..._buildVariations(
                match.character,
                matrixNormalized,
                [0, 1, 2, 3]
                    .where((number) => number != match.matrixIndex)
                    .toList(),
              ),
            ],
          ),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildVariations(
    final String character,
    final Matrix matrixFound,
    final List<int> matrixIndexes,
  ) {
    List<Widget> widgets = [];
    for (final matrixIndex in matrixIndexes) {
      final variation = _buildVariation(character, matrixFound, matrixIndex);
      if (variation != null) {
        widgets.add(variation);
      }
    }
    return widgets;
  }

  Widget? _buildVariation(
    final String character,
    final Matrix matrixFound,
    final int matrixIndex,
  ) {
    final CharacterDefinition? definition =
        widget.textify.characterDefinitions.getDefinition(character);
    if (definition != null && matrixIndex < definition.matrices.length) {
      final templatedMatrix = definition.matrices[matrixIndex];

      final double scoreForThisVariation = Matrix.hammingDistancePercentage(
            matrixFound,
            templatedMatrix,
          ) *
          100;

      final Matrix characterMatrix =
          widget.textify.characterDefinitions.getMatrix(character, matrixIndex);

      return _buildArtifactGrid(
        '"$character" [${templatedMatrix.font}]\nScore ${scoreForThisVariation.toStringAsFixed(2)}%',
        Colors.grey.shade900,
        matrixFound,
        characterMatrix,
        characterMatrix..gridToString(forCode: true),
      );
    }
    return null;
  }
}
