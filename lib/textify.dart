import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:textify/artifact.dart';
import 'package:textify/bands.dart';
import 'package:textify/character_definitions.dart';
import 'package:textify/correction.dart';
import 'package:textify/matrix.dart';
import 'package:textify/score_match.dart';

/// Textify is a class designed to extract text from clean digital images.
///
/// This class provides functionality to process binary images, identify text artifacts,
/// organize them into bands, and extract the text content. It is optimized for
/// clean computer-generated documents with standard fonts and good contrast.
class Textify {
  /// Stores definitions of characters for matching.
  final CharacterDefinitions characterDefinitions = CharacterDefinitions();

  /// identified regions on the image
  List<Rect> regionsFromDilated = [];

  /// List of text bands identified in the image.
  Bands bands = Bands();

  /// The extracted text from the image.
  String textFound = '';

  /// Represents the start time of a process or operation.
  DateTime processBegin = DateTime.now();

  /// Represents the end time of a process or operation.
  DateTime processEnd = DateTime.now();

  /// Calculates the duration, in milliseconds, between the start and end times
  /// of a process or operation.
  ///
  /// The duration is calculated by subtracting the number of milliseconds since
  /// the Unix epoch for the start time (`processBegin`) from the number of
  /// milliseconds since the Unix epoch for the end time (`processedEnd`).
  ///
  /// Returns:
  ///   An integer representing the duration, in milliseconds, between the start
  ///   and end times of the process or operation.
  int get duration =>
      processEnd.millisecondsSinceEpoch - processBegin.millisecondsSinceEpoch;

  /// Ignore horizontal and vertical lines
  bool excludeLongLines = true;

  /// The size of the dilation operation used in the text recognition process.
  ///
  /// This value determines the size of the dilation kernel used to expand the
  /// detected text artifacts. A larger value can help merge nearby characters
  /// into a single artifact, but may also merge unrelated artifacts. The
  /// optimal value depends on the quality and resolution of the input images.
  int dilatingSize = 22;

  /// WHen letters are touching
  bool innerSplit = false;

  /// Whether to apply dictionary-based corrections during text recognition.
  ///
  /// When set to true, the recognition process will attempt to correct potential
  /// misidentified characters by comparing them against a dictionary of known words.
  /// This can improve accuracy but may increase processing time.
  bool applyDictionary = false;

  /// Initializes the Textify instance by loading character definitions.
  ///
  /// [pathToAssetsDefinition] is the path to the JSON file containing character definitions.
  /// Returns a [Future<bool>] indicating whether the initialization was successful.
  Future<Textify> init({
    final String pathToAssetsDefinition =
        'packages/textify/assets/matrices.json',
  }) async {
    await characterDefinitions.loadDefinitions(pathToAssetsDefinition);
    return this;
  }

  /// Clears all stored data, resetting the Textify instance.
  void clear() {
    bands.clear();
    textFound = '';
  }

  /// The width of the character template used for recognition.
  ///
  /// This getter returns the standard width of the template used to define
  /// characters in the recognition process. It's derived from the
  /// [CharacterDefinition] class.
  ///
  /// Returns:
  ///   An [int] representing the width of the character template in pixels.
  int get templateWidth => CharacterDefinition.templateWidth;

  /// The height of the character template used for recognition.
  ///
  /// This getter returns the standard height of the template used to define
  /// characters in the recognition process. It's derived from the
  /// [CharacterDefinition] class.
  ///
  /// Returns:
  ///   An [int] representing the height of the character template in pixels.
  int get templateHeight => CharacterDefinition.templateHeight;

  /// The number of items in the list.
  ///
  /// This getter returns the current count of items in the list. It's a
  /// convenient way to access the length property of the underlying list.
  ///
  /// Returns:
  ///   An [int] representing the number of items in the list.
  int get count => bands.totalArtifacts;

  /// Finds matching character scores for a given artifact.
  ///
  /// [artifact] is the artifact to find matches for.
  /// [supportedCharacters] is an optional string of characters to limit the search to.
  ///
  /// Returns:
  ///   A list of [ScoreMatch] objects sorted by descending score.
  List<ScoreMatch> getMatchingScoresOfNormalizedMatrix(
    final Artifact artifact, [
    final String supportedCharacters = '',
  ]) {
    final Matrix matrix = artifact.matrix;
    final int numberOfEnclosure = matrix.enclosures;
    final bool hasVerticalLineOnTheLeftSide = matrix.verticalLineLeft;
    final bool hasVerticalLineOnTheRightSide = matrix.verticalLineRight;
    final bool punctuation = matrix.isPunctuation();

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
      // Enclosures
      if (numberOfEnclosure == template.enclosures) {
        matchingChecks++;
      }

      // Punctuation
      if (punctuation == template.isPunctuation) {
        matchingChecks++;
      }

      // Left Line
      if (hasVerticalLineOnTheLeftSide == template.lineLeft) {
        matchingChecks++;
      }

      // Right Line
      if (hasVerticalLineOnTheRightSide == template.lineRight) {
        matchingChecks++;
      }

      // Calculate match percentage
      final double matchPercentage = matchingChecks / totalChecks;

      // Include templates that meet or exceed the percentage needed
      return matchPercentage >= percentageNeeded;
    }).toList();

    if (qualifiedTemplates.isEmpty) {
      qualifiedTemplates = characterDefinitions.definitions;
    }

    final Matrix resizedMatrix =
        matrix.createNormalizeMatrix(templateWidth, templateHeight);

    // Calculate the final scores
    final List<ScoreMatch> scores =
        _getDistanceScores(qualifiedTemplates, resizedMatrix);

    // Sort scores in descending order (higher score is better)
    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores;
  }

  /// Extracts text from an image.
  ///
  /// This method converts the input image to black and white, transforms it into a matrix,
  /// and then uses the [getTextFromMatrix] method to perform the actual text recognition.
  ///
  /// Parameters:
  /// - [image]: A [ui.Image] object representing the image from which to extract text.
  ///   This parameter is required.
  /// - [supportedCharacters]: An optional string containing the set of characters
  ///   to be recognized. If provided, the text extraction will be limited to these
  ///   characters. Default is an empty string, which means all supported characters
  ///   will be considered.
  ///
  /// Returns:
  /// A [Future<String>] that resolves to the extracted text from the image.
  ///
  /// Throws:
  /// May throw exceptions related to image processing or text extraction failures.
  ///
  /// Usage:
  /// ```dart
  /// final ui.Image myImage = // ... obtain image
  /// final String extractedText = await getTextFromImage(image: myImage);
  /// print(extractedText);
  /// ```
  Future<String> getTextFromImage({
    required final ui.Image image,
    final String supportedCharacters = '',
  }) async {
    final ui.Image imageBlackAndWhite = await imageToBlackOnWhite(image);

    final Matrix imageAsMatrix = await Matrix.fromImage(imageBlackAndWhite);

    return await getTextFromMatrix(
      imageAsMatrix: imageAsMatrix,
      supportedCharacters: supportedCharacters,
    );
  }

  /// Extracts text from a binary image.
  ///
  /// [imageAsMatrix] is the binary representation of the image.
  /// [supportedCharacters] is an optional string of characters to limit the recognition to.
  /// Returns the extracted text as a string.
  Future<String> getTextFromMatrix({
    required final Matrix imageAsMatrix,
    final String supportedCharacters = '',
  }) async {
    assert(
      characterDefinitions.count > 0,
      'No character definitions loaded, did you forget to call Init()',
    );

    /// Start
    processBegin = DateTime.now();

    identifyArtifactsAndBandsInBinaryImage(imageAsMatrix);

    String result = await getTextFromArtifacts(
      listOfBands: this.bands.list,
      supportedCharacters: supportedCharacters,
    );

    processEnd = DateTime.now();
    // End

    return result;
  }

  /// Processes a binary image to find, merge, and categorize artifacts.
  ///
  /// This method takes a binary image represented as a [Matrix] and performs
  /// a series of operations to identify and process artifacts within the image.
  ///
  /// The process involves three main steps:
  /// 1. Finding individual artifacts in the image.
  /// 2. Merging disconnected parts of artifacts that likely belong together.
  /// 3. Creating bands based on the positions of the merged artifacts.
  ///
  /// Parameters:
  ///   [matrixSourceImage] - A [Matrix] representing the binary image to be processed.
  ///
  /// The method does not return a value, but updates internal state to reflect
  /// the found artifacts and bands.
  ///
  /// Note: This method assumes that the input [Matrix] is a valid binary image.
  /// Behavior may be undefined for non-binary input.
  void identifyArtifactsAndBandsInBinaryImage(final Matrix matrixSourceImage) {
    // Clear existing artifacts
    clear();

    // Create a dilated copy of the binary image to merge nearby pixels
    int kernelSize =
        computeKernelSize(matrixSourceImage.cols, matrixSourceImage.rows, 0.02);
    final Matrix dilatedImage = dilateMatrix(
      matrixImage: matrixSourceImage,
      kernelSize: kernelSize,
    );

    //
    // Regions
    //
    this.regionsFromDilated = findRegions(dilatedMatrixImage: dilatedImage);

    // Explore each regions/rectangles
    this.bands = Bands.getBandsOfArtifacts(
      matrixSourceImage,
      this.regionsFromDilated,
    );
  }

  /// Determines the most likely character represented by an artifact.
  ///
  /// This method analyzes the given artifact and attempts to match it against
  /// a set of supported characters, returning the best match.
  ///
  /// Parameters:
  ///   [artifact]: The Artifact object to be analyzed. This typically represents
  ///               a segment of an image that potentially contains a character.
  ///   [supportedCharacters]: An optional string containing all the characters
  ///                          that should be considered in the matching process.
  ///                          If empty, all possible characters are considered.
  ///
  /// Returns:
  ///   A String containing the best matching character. If no match is found
  ///   or if the scores list is empty, an empty string is returned.
  ///
  /// Note:
  ///   This method relies on the `getMatchingScores` function to perform the
  ///   actual character matching and scoring. The implementation of
  ///   `getMatchingScores` is crucial for the accuracy of this method.
  String _getCharacterFromArtifactNormalizedMatrix(
    final Artifact artifact, [
    final String supportedCharacters = '',
  ]) {
    final List<ScoreMatch> scores =
        getMatchingScoresOfNormalizedMatrix(artifact, supportedCharacters);

    return scores.isNotEmpty ? scores.first.character : '';
  }

  /// Calculates the distance scores between an input matrix and a set of character templates.
  ///
  /// This method iterates through each character template, calculates the Hamming distance
  /// percentage between the input matrix and each matrix in the template, and creates a
  /// [ScoreMatch] object for each comparison. The [ScoreMatch] objects are then sorted in
  /// descending order by their score.
  ///
  /// If there is a tie between the top two [ScoreMatch] objects, a tie-breaker is implemented
  /// by calculating the average Hamming distance percentage for all matrices in each template
  /// and swapping the top two [ScoreMatch] objects if the second template has a higher average.
  ///
  /// Parameters:
  ///   [templates]: A list of [CharacterDefinition] objects representing the character templates
  ///                to compare against.
  ///   [inputMatrix]: The input matrix to compare against the character templates.
  ///
  /// Returns:
  ///   A list of [ScoreMatch] objects representing the distance scores between the input matrix
  ///   and the character templates, sorted in descending order by score.
  static List<ScoreMatch> _getDistanceScores(
    List<CharacterDefinition> templates,
    Matrix inputMatrix,
  ) {
    final List<ScoreMatch> scores = [];
    // Iterate through each template in the map
    for (final CharacterDefinition template in templates) {
      // Calculate the similarity score and create a ScoreMatch object
      for (int i = 0; i < template.matrices.length; i++) {
        final Matrix matrix = template.matrices[i];
        final ScoreMatch scoreMatch = ScoreMatch(
          character: template.character,
          matrixIndex: i,
          score: Matrix.hammingDistancePercentage(
            inputMatrix,
            matrix,
          ),
        );

        // Add the ScoreMatch to the scores list
        scores.add(scoreMatch);
      }
    }

    // Sort the scores list in descending order of score 1.0 to 0.0
    scores.sort((a, b) => b.score.compareTo(a.score));

    if (scores.length >= 2) {
      // Implement tie breaker
      if (scores[0].score == scores[1].score) {
        final CharacterDefinition template1 = templates.firstWhere(
          (t) => t.character == scores[0].character,
        );
        final CharacterDefinition template2 = templates.firstWhere(
          (t) => t.character == scores[1].character,
        );

        double totalScore1 = 0;
        double totalScore2 = 0;

        for (final matrix in template1.matrices) {
          totalScore1 += Matrix.hammingDistancePercentage(
            inputMatrix,
            matrix,
          );
        }
        totalScore1 /= template1.matrices.length; // averaging

        for (final matrix in template2.matrices) {
          totalScore2 += Matrix.hammingDistancePercentage(
            inputMatrix,
            matrix,
          );
        }

        totalScore2 /= template2.matrices.length; // averaging

        if (totalScore2 > totalScore1) {
          // Swap the first two elements if the second template has a higher total score
          final temp = scores[0];
          scores[0] = scores[1];
          scores[1] = temp;
        }
      }
    }

    return scores;
  }

  /// Processes the list of artifacts to extract and format the text content.
  ///
  /// This method performs a series of operations to convert visual artifacts
  /// (likely representing characters or words in an image) into a coherent
  /// string of text, while attempting to preserve the original layout.
  ///
  /// The process involves several phases:
  /// 1. Grouping artifacts into text rows
  /// 2. Merging overlapping artifacts
  /// 3. Adjusting artifacts to match the height of their respective rows
  /// 4. Sorting artifacts in reading order (left to right, top to bottom)
  /// 5. Extracting text from each artifact and combining into a single string
  ///
  /// The method also handles formatting by adding spaces between different
  /// rows to maintain the structure of the original text.
  ///
  /// Returns:
  ///   A String containing the extracted text, with attempts made to preserve
  ///   the original layout through the use of spaces between rows.
  Future<String> getTextFromArtifacts({
    required final List<Band> listOfBands,
    final String supportedCharacters = '',
  }) async {
    this.textFound = '';

    final List<String> linesFound = [];

    for (final Band band in listOfBands) {
      String line = '';

      for (final Artifact artifact in band.artifacts) {
        artifact.characterMatched = _getCharacterFromArtifactNormalizedMatrix(
          artifact,
          supportedCharacters,
        );

        line += artifact.characterMatched;
      }
      linesFound.add(line);
    }

    this.textFound += linesFound.join('\n');

    if (applyDictionary) {
      this.textFound = applyDictionaryCorrection(this.textFound);
    }

    return textFound.trim(); // Trim to remove leading space
  }
}

/// Loads an image from the specified asset path.
///
/// This function asynchronously loads an image from the specified asset path and
/// returns a [Future] that completes with the loaded [ui.Image] instance.
///
/// The function uses [AssetImage] to resolve the image and listens to the
/// [ImageStream] to get the loaded image.
///
/// Example usage:
///
/// final image = await loadImage('assets/my_image.png');
///
Future<ui.Image> loadImageFromAssets(String assetPath) async {
  final assetImage = AssetImage(assetPath);
  final completer = Completer<ui.Image>();
  assetImage.resolve(ImageConfiguration.empty).addListener(
        ImageStreamListener((info, _) => completer.complete(info.image)),
      );
  return completer.future;
}
