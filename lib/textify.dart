/// This library is part of the Textify package.
/// Provides the main interface for text extraction from images.
library;

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import 'package:textify/bands.dart';
import 'package:textify/character_definitions.dart';
import 'package:textify/correction.dart';
import 'package:textify/score_match.dart';
import 'package:textify/utilities.dart';

/// Textify is a class designed to extract text from clean digital images.
///
/// This class provides functionality to process binary images, identify text artifacts,
/// organize them into bands, and extract the text content. It is optimized for
/// clean computer-generated documents with standard fonts and good contrast.
class Textify {
  /// Creates a new instance of Textify.
  Textify();

  /// Stores definitions of characters for matching.
  final CharacterDefinitions characterDefinitions = CharacterDefinitions();

  /// Identified regions on the image after dilation processing.
  List<IntRect> regionsFromDilated = [];

  /// List of text bands identified in the image.
  /// Each band represents a horizontal line of text.
  Bands bands = Bands();

  /// The extracted text from the image after processing.
  String textFound = '';

  /// Timestamp when the text extraction process begins.
  DateTime processBegin = DateTime.now();

  /// Timestamp when the text extraction process ends.
  DateTime processEnd = DateTime.now();

  /// Duration in milliseconds between process start and end.
  ///
  /// Calculates the time taken for text extraction by finding the difference
  /// between processEnd and processBegin timestamps.
  int get duration =>
      processEnd.millisecondsSinceEpoch - processBegin.millisecondsSinceEpoch;

  /// Whether to exclude long horizontal and vertical lines from text recognition.
  /// When true, lines that span a significant portion of the image are ignored.
  bool excludeLongLines = true;

  /// Size of the dilation kernel used in preprocessing.
  ///
  /// Controls how much nearby pixels are merged together. Larger values help
  /// connect broken characters but may merge unrelated elements.
  int dilatingSize = 22;

  /// Whether to attempt splitting touching characters.
  /// When true, the system tries to separate characters that are connected.
  bool innerSplit = true;

  /// Whether to apply dictionary-based text correction.
  ///
  /// When enabled, recognized text is compared against a dictionary
  /// to improve accuracy by correcting likely mis-recognitions.
  bool applyDictionary = false;

  /// Initializes Textify by loading character definitions from assets.
  ///
  /// [pathToAssetsDefinition] specifies the JSON file containing character matrices.
  /// Returns the initialized Textify instance.
  Future<Textify> init({
    final String pathToAssetsDefinition =
        'packages/textify/assets/matrices.json',
  }) async {
    await characterDefinitions.loadDefinitions(pathToAssetsDefinition);
    return this;
  }

  /// Resets the Textify instance to its initial state.
  /// Clears all bands and extracted text.
  void clear() {
    bands.clear();
    textFound = '';
  }

  /// Width of the character template used for recognition.
  /// Standardized width for comparing characters.
  int get templateWidth => CharacterDefinition.templateWidth;

  /// Height of the character template used for recognition.
  /// Standardized height for comparing characters.
  int get templateHeight => CharacterDefinition.templateHeight;

  /// Total number of artifacts (potential characters) identified.
  int get count => bands.totalArtifacts;

  /// Extracts text from a Flutter Image object.
  ///
  /// [image] is the source image to process.
  /// [supportedCharacters] optionally limits recognition to specific characters.
  /// Returns the extracted text as a string.
  Future<String> getTextFromImage({
    required final ui.Image image,
    final String supportedCharacters = '',
  }) async {
    final ui.Image imageBlackAndWhite = await imageToBlackOnWhite(image);

    final Artifact imageAsArtifact = await artifactFromImage(
      imageBlackAndWhite,
    );

    return await getTextFromMatrix(
      imageAsMatrix: imageAsArtifact,
      supportedCharacters: supportedCharacters,
    );
  }

  /// Extracts text from a binary matrix representation.
  ///
  /// [imageAsMatrix] is the binary image data.
  /// [supportedCharacters] optionally limits recognition to specific characters.
  /// Returns the extracted text as a string.
  Future<String> getTextFromMatrix({
    required final Artifact imageAsMatrix,
    final String supportedCharacters = '',
  }) async {
    assert(
      characterDefinitions.count > 0,
      'No character definitions loaded, did you forget to call Init()',
    );

    processBegin = DateTime.now();

    extractBandsAndArtifacts(imageAsMatrix);

    String result = await getTextInBands(
      listOfBands: this.bands.list,
      supportedCharacters: supportedCharacters,
    );

    processEnd = DateTime.now();

    return result;
  }

  /// Processes image to identify text regions and organize into bands.
  ///
  /// [matrixSourceImage] is the binary image to process.
  /// Updates internal state with found regions and text bands.
  ///
  /// This method performs three key steps:
  /// 1. Dilates the image to connect nearby pixels using an adaptive kernel size
  /// 2. Identifies text regions from the dilated image
  /// 3. Groups the regions into horizontal bands of text
  void extractBandsAndArtifacts(final Artifact matrixSourceImage) {
    clear();

    int kernelSize = computeKernelSize(
      matrixSourceImage.cols,
      matrixSourceImage.rows,
      0.02,
    );
    final Artifact dilatedImage = dilateArtifact(
      matrixImage: matrixSourceImage,
      kernelSize: kernelSize,
    );

    this.regionsFromDilated = dilatedImage.findSubRegions();

    this.bands = Bands.getBandsOfArtifacts(
      matrixSourceImage,
      this.regionsFromDilated,
      this.innerSplit,
    );
  }

  /// Calculates similarity scores between a matrix and character templates.
  ///
  /// [templates] are the character definitions to compare against.
  /// [inputMatrix] is the normalized character image.
  /// Returns sorted list of match scores, best matches first.
  static List<ScoreMatch> _getDistanceScores(
    List<CharacterDefinition> templates,
    Artifact inputMatrix,
  ) {
    final List<ScoreMatch> scores = [];

    // Calculate average score for each character definition
    for (final CharacterDefinition template in templates) {
      double totalScore = 0;
      double bestScore = 0;
      int bestMatrixIndex = 0;

      // Find best match and calculate total score
      for (int i = 0; i < template.matrices.length; i++) {
        final Artifact artifact = template.matrices[i];
        final double score = hammingDistancePercentageOfTwoArtifacts(
          inputMatrix,
          artifact,
        );

        totalScore += score;

        if (score > bestScore) {
          bestScore = score;
          bestMatrixIndex = i;
        }
      }

      // Calculate weighted score: 70% best match, 30% average across all templates
      final double avgScore = template.matrices.isEmpty
          ? 0
          : totalScore / template.matrices.length;
      final double combinedScore = (bestScore * 0.7) + (avgScore * 0.3);

      scores.add(
        ScoreMatch(
          character: template.character,
          matrixIndex: bestMatrixIndex,
          score: combinedScore,
        ),
      );
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores;
  }

  /// Converts identified artifacts into text.
  ///
  /// [listOfBands] contains grouped artifacts representing lines of text.
  /// [supportedCharacters] optionally limits recognition to specific characters.
  /// Returns extracted text with preserved line breaks.
  Future<String> getTextInBands({
    required final List<Band> listOfBands,
    final String supportedCharacters = '',
  }) async {
    this.textFound = '';
    final List<String> linesFound = [];

    for (final Band band in listOfBands) {
      String line = '';

      // Process each band until no more splits are needed
      bool needsReprocessing;
      do {
        needsReprocessing = false;

        // Use index-based loop to handle list modifications
        for (int i = 0; i < band.artifacts.length; i++) {
          final Artifact artifact = band.artifacts[i];

          // Skip artifacts that have already been processed
          if (artifact.matchingCharacter.isNotEmpty) {
            continue;
          }

          final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
            artifact,
            supportedCharacters,
          );

          if (scores.isEmpty) {
            continue;
          }

          if (scores.first.score < 0.4) {
            artifact.needsInspection = true;
            final List<Artifact> artifactsFromColumns = band.splitChunk(
              artifact,
            );

            if (artifactsFromColumns.isNotEmpty) {
              band.replaceOneArtifactWithMore(artifact, artifactsFromColumns);
              needsReprocessing = true;
              break; // Exit the loop to restart with the new artifacts
            }
          }

          artifact.matchingScore = scores.first.score;
          artifact.matchingCharacter = scores.first.character;
        }
      } while (needsReprocessing);

      // Build the final line from processed artifacts
      band.sortArtifactsLeftToRight();
      for (final Artifact artifact in band.artifacts) {
        line += artifact.matchingCharacter;
      }

      linesFound.add(line);
    }

    this.textFound += linesFound.join('\n');
    this.textFound = applyCorrection(this.textFound, applyDictionary);

    return textFound.trim();
  }

  /// Calculates character match scores for a normalized artifact.
  ///
  /// [artifact] is the normalized character image.
  /// [supportedCharacters] optionally limits matching to specific characters.
  /// Returns sorted list of match scores, best matches first.
  List<ScoreMatch> getMatchingScoresOfNormalizedMatrix(
    final Artifact artifact, [
    final String supportedCharacters = '',
  ]) {
    final int numberOfEnclosure = artifact.enclosures;
    final bool hasVerticalLineOnTheLeftSide = artifact.verticalLineLeft;
    final bool hasVerticalLineOnTheRightSide = artifact.verticalLineRight;
    final bool punctuation = artifact.isPunctuation();

    const double percentageNeeded = 0.5;
    const int totalChecks = 4;

    List<CharacterDefinition> qualifiedTemplates = characterDefinitions
        .definitions
        .where((final CharacterDefinition template) {
          if (supportedCharacters.isNotEmpty &&
              !supportedCharacters.contains(template.character)) {
            return false;
          }

          int matchingChecks = 0;
          if (numberOfEnclosure == template.enclosures) {
            matchingChecks++;
          }
          if (punctuation == template.isPunctuation) {
            matchingChecks++;
          }
          if (hasVerticalLineOnTheLeftSide == template.lineLeft) {
            matchingChecks++;
          }
          if (hasVerticalLineOnTheRightSide == template.lineRight) {
            matchingChecks++;
          }

          final double matchPercentage = matchingChecks / totalChecks;
          return matchPercentage >= percentageNeeded;
        })
        .toList();

    final Artifact resizedArtifact = artifact.createNormalizeMatrix(
      templateWidth,
      templateHeight,
    );

    final List<ScoreMatch> scores = _getDistanceScores(
      qualifiedTemplates,
      resizedArtifact,
    );

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores;
  }

  /// Loads an image from the asset bundle.
  ///
  /// [assetPath] is the path to the image asset.
  /// Returns the loaded image as a ```Future<ui.Image>.```
  static Future<ui.Image> loadImageFromAssets(String assetPath) async {
    final assetImage = AssetImage(assetPath);
    final completer = Completer<ui.Image>();
    assetImage
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((info, _) => completer.complete(info.image)),
        );
    return completer.future;
  }
}
