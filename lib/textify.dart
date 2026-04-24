/// This library is part of the Textify package.
/// Provides the main interface for text extraction from images.
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:textify/artifact_analysis.dart';
import 'package:textify/artifact_grid_transform.dart';
import 'package:textify/artifact_morphology.dart';
import 'package:textify/artifact_projection.dart';
import 'package:textify/artifact_region.dart';
import 'package:textify/bands.dart';
import 'package:textify/char_utils.dart';
import 'package:textify/character_definitions.dart';
import 'package:textify/constants.dart';
import 'package:textify/correction.dart';
import 'package:textify/image_helpers.dart';
import 'package:textify/models/score_match.dart';
import 'package:textify/models/textify_config.dart';
import 'package:textify/textify_post_process.dart';

/// Main OCR class for extracting text from clean digital images.
///
/// Processes images by identifying text regions, organizing them into lines (bands),
/// and recognizing characters using template matching.
class Textify {
  static const double _lowerRightStrokeSwapDelta = 0.06;
  static const double _lowercaseMToUAspectRatioThreshold = 1.05;
  static const double _lowercaseMUScoreDelta = 0.08;
  static const int _lowercaseMToUStemThreshold = 2;
  static const double _letterOverPunctuationDelta = 0.05;
  static const double _letterDominanceRatio = 0.6;
  static const double _bandContextPromotionDelta = 0.22;
  static const double _uppercaseDominanceRatio = 0.70;
  static const int _mergeGapWidthDivisor = 2;
  static const double _mergeScoreThreshold = 0.6;
  static const double _mergeScoreDelta = 0.05;
  static const double _mergeNarrowWidthRatio = 0.6;
  static const double _mergeMaxWidthRatio = 1.3;
  static const int _weakArtifactMaxWidth = 10;
  static const double _structuralTieBreakDelta = 0.02;
  static const double _scoreEqualityTolerance = 1e-9;
  static const int _minimumTieBreakCandidates = 2;
  static const int _characterCategoryLetter = 1;
  static const int _characterCategoryDigit = 2;
  static const int _characterCategoryOther = 3;

  /// Creates a new instance of Textify with the specified configuration.
  ///
  /// [config] defines the OCR processing settings. If not provided,
  /// uses the balanced configuration with default settings.
  Textify({this.config = const TextifyConfig()});

  /// The configuration settings for this Textify instance.
  final TextifyConfig config;

  /// Stores definitions of characters for matching.
  static final CharacterDefinitions characterDefinitions =
      CharacterDefinitions();

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

  /// Whether to attempt splitting touching characters.
  /// When true, the system tries to separate characters that are connected.
  bool get innerSplit => config.attemptCharacterSplitting;

  /// Whether to apply dictionary-based text correction.
  ///
  /// When enabled, recognized text is compared against a dictionary
  /// to improve accuracy by correcting likely mis-recognitions.
  bool get applyDictionary => config.applyDictionaryCorrection;

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

    final Artifact imageAsArtifact = await Artifact.artifactFromImage(
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
      TextifyErrors.noCharacterDefinitions,
    );

    processBegin = DateTime.now();

    extractBandsAndArtifacts(imageAsMatrix);

    String result =
        await getTextInBands(
          listOfBands: bands.list,
          supportedCharacters: supportedCharacters,
        ).timeout(
          Duration(milliseconds: config.maxProcessingTimeMs),
          onTimeout: () => textFound,
        );

    processEnd = DateTime.now();

    return result;
  }

  /// Processes image to identify text regions and organize into bands.
  ///
  /// [matrixSourceImage] is the binary image to process.
  /// Updates internal state with found regions and text bands.
  ///
  /// Uses histogram projection (XY-cut) to segment the image:
  /// 1. Horizontal projection finds text line rows
  /// 2. Connected components within each line find individual characters
  /// 3. Existing merge logic handles multi-component characters (i, j, etc.)
  void extractBandsAndArtifacts(final Artifact matrixSourceImage) {
    clear();

    final Artifact cleanedSourceImage = config.excludeLongLines
        ? matrixSourceImage.removeDecorativeLineComponents()
        : matrixSourceImage;

    // Step 1: Find text lines via horizontal projection (replaces dilation)
    final List<IntRect> textLineRects = findTextLineRects(cleanedSourceImage);
    regionsFromDilated = textLineRects;

    // Step 2: For each text line, use connected components to find characters
    for (final IntRect lineRect in textLineRects) {
      final Artifact lineArtifact = cleanedSourceImage.extractSubGrid(
        rect: lineRect,
      );

      bands.add(
        Band.splitArtifactIntoBand(
          regionMatrix: lineArtifact,
          offset: lineRect.topLeft,
        ),
      );
    }

    // Clean up bands
    bands.removeEmptyBands();

    for (final Band band in bands.list) {
      for (final a in band.artifacts) {
        a.locationAdjusted = IntOffset(a.locationFound.x, a.locationFound.y);
      }
      band.sortArtifactsLeftToRight();
    }

    Bands.sortVerticallyThenHorizontally(bands.list);

    for (final Band band in bands.list) {
      band.padVerticallyArtifactToMatchTheBand();
      if (innerSplit) {
        band.identifySuspiciousLargeArtifacts();
      }
      band.identifySpacesInBand();
      band.packArtifactLeftToRight();
    }
  }

  /// Maximum number of candidates to run full Hamming comparison on.
  static const int _histogramTopK = 15;

  /// Confidence threshold below which the fallback expansion runs.
  static const double _histogramFallbackThreshold = 0.6;

  /// Calculates similarity scores between a matrix and character templates.
  ///
  /// Uses histogram pre-ranking to limit expensive Hamming comparisons
  /// to the top-K most promising candidates.
  ///
  /// [templates] are the character definitions to compare against.
  /// [inputMatrix] is the normalized character image.
  /// Returns sorted list of match scores, best matches first.
  static List<ScoreMatch> _getDistanceScores(
    List<CharacterDefinition> templates,
    Artifact inputMatrix,
  ) {
    if (templates.isEmpty) {
      return const [];
    }

    // Pre-rank by histogram similarity (cheap: 100 int comparisons each)
    final List<int> inputColHist = _columnHistogram(inputMatrix);
    final List<int> inputRowHist = _rowHistogram(inputMatrix);

    final List<_HistogramRankedCandidate> ranked = [];
    for (int i = 0; i < templates.length; i++) {
      final double histScore = templates[i].histogramSimilarity(
        inputColHist,
        inputRowHist,
      );
      ranked.add(_HistogramRankedCandidate(index: i, histScore: histScore));
    }
    ranked.sort((a, b) => b.histScore.compareTo(a.histScore));

    // Run Hamming on top-K candidates
    final int firstBatch = min(_histogramTopK, ranked.length);
    final List<ScoreMatch> scores = _hammingScoreBatch(
      templates,
      inputMatrix,
      ranked,
      0,
      firstBatch,
    );

    scores.sort((a, b) => b.score.compareTo(a.score));

    // Fallback: if best score is weak, expand to remaining candidates
    if (scores.isNotEmpty &&
        scores.first.score < _histogramFallbackThreshold &&
        firstBatch < ranked.length) {
      final List<ScoreMatch> fallbackScores = _hammingScoreBatch(
        templates,
        inputMatrix,
        ranked,
        firstBatch,
        ranked.length,
      );
      scores.addAll(fallbackScores);
      scores.sort((a, b) => b.score.compareTo(a.score));
    }

    return scores;
  }

  /// Runs Hamming distance comparison for a range of ranked candidates.
  static List<ScoreMatch> _hammingScoreBatch(
    List<CharacterDefinition> templates,
    Artifact inputMatrix,
    List<_HistogramRankedCandidate> ranked,
    int startIndex,
    int endIndex,
  ) {
    final Artifact erodedInput = inputMatrix.erodeSoft();
    final List<ScoreMatch> scores = [];

    for (int r = startIndex; r < endIndex; r++) {
      final CharacterDefinition template = templates[ranked[r].index];
      double totalScore = 0;
      double bestScore = 0;
      int bestMatrixIndex = 0;

      for (int i = 0; i < template.matrices.length; i++) {
        final Artifact artifact = template.matrices[i];
        final double scoreOriginal =
            Artifact.hammingDistancePercentageOfTwoArtifacts(
              inputMatrix,
              artifact,
            );
        final double scoreEroded =
            Artifact.hammingDistancePercentageOfTwoArtifacts(
              erodedInput,
              artifact,
            );
        final double score = scoreOriginal > scoreEroded
            ? scoreOriginal
            : scoreEroded;

        totalScore += score;

        if (score > bestScore) {
          bestScore = score;
          bestMatrixIndex = i;
        }
      }

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

    return scores;
  }

  /// Computes column histogram (pixel count per column) for an artifact.
  static List<int> _columnHistogram(Artifact artifact) {
    final List<int> hist = List<int>.filled(artifact.cols, 0);
    for (int x = 0; x < artifact.cols; x++) {
      for (int y = 0; y < artifact.rows; y++) {
        if (artifact.cellGet(x, y)) {
          hist[x]++;
        }
      }
    }
    return hist;
  }

  /// Computes row histogram (pixel count per row) for an artifact.
  static List<int> _rowHistogram(Artifact artifact) {
    final List<int> hist = List<int>.filled(artifact.rows, 0);
    for (int y = 0; y < artifact.rows; y++) {
      for (int x = 0; x < artifact.cols; x++) {
        if (artifact.cellGet(x, y)) {
          hist[y]++;
        }
      }
    }
    return hist;
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
    textFound = '';
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

          if (_tryMergeAdjacentLineLikeArtifacts(
            band,
            i,
            artifact,
            scores.first.score,
            supportedCharacters,
          )) {
            needsReprocessing = true;
            break;
          }

          if (scores.first.score < config.matchingThreshold) {
            artifact.needsInspection = true;
            final List<Artifact> artifactsFromColumns = band.splitChunk(
              artifact,
            );

            if (artifactsFromColumns.isNotEmpty &&
                _splitImprovesScore(
                  artifactsFromColumns,
                  scores.first.score,
                  supportedCharacters,
                )) {
              band.replaceOneArtifactWithMore(artifact, artifactsFromColumns);
              needsReprocessing = true;
              break; // Exit the loop to restart with the new artifacts
            }
          }

          final double weakArtifactThreshold = max(
            0,
            config.matchingThreshold - _mergeScoreDelta,
          );
          final bool weakTinyArtifact =
              scores.first.score < weakArtifactThreshold &&
              (artifact.rectFound.width <= _weakArtifactMaxWidth ||
                  artifact.isPunctuation());
          if (weakTinyArtifact) {
            continue;
          }

          artifact.matchingScore = scores.first.score;
          artifact.matchingCharacter = scores.first.character;
        }
      } while (needsReprocessing);

      // Build the final line from processed artifacts
      band.sortArtifactsLeftToRight();
      _reMergeConsecutiveVerticalStrokes(band);
      _refinePunctuationInLetterContext(band);
      _refineUppercaseInUppercaseContext(band);
      for (final Artifact artifact in band.artifacts) {
        line += artifact.matchingCharacter;
      }

      linesFound.add(line);
    }

    textFound += linesFound.join('\n');
    textFound = applyCorrection(textFound, applyDictionary);
    textFound = postProcessText(textFound, applyDictionary: applyDictionary);

    return textFound.trim();
  }

  /// Attempts to merge adjacent line-like fragments into a single glyph.
  bool _tryMergeAdjacentLineLikeArtifacts(
    Band band,
    int index,
    Artifact current,
    double currentScore,
    String supportedCharacters,
  ) {
    if (index >= band.artifacts.length - 1) {
      return false;
    }

    final Artifact next = band.artifacts[index + 1];
    if (next.matchingCharacter.isNotEmpty) {
      return false;
    }

    final bool lineLikePair =
        current.isConsideredLine() && next.isConsideredLine();
    final int avgWidth = band.averageWidth;
    final bool narrowPair =
        avgWidth > 0 &&
        current.rectFound.width <= (avgWidth * _mergeNarrowWidthRatio) &&
        next.rectFound.width <= (avgWidth * _mergeNarrowWidthRatio);

    final int gap = next.rectFound.left - current.rectFound.right;
    final int maxGap = band.averageKerning <= 0
        ? max(1, avgWidth ~/ 2)
        : max(1, min(avgWidth ~/ 2, band.averageKerning * 2));
    if (gap < 0 || gap > maxGap) {
      return false;
    }

    final bool widthEligible =
        avgWidth > 0 &&
        (current.rectFound.width + next.rectFound.width + gap) <=
            (avgWidth * _mergeMaxWidthRatio);

    if (!lineLikePair && !narrowPair && !widthEligible && gap > 1) {
      return false;
    }

    final List<ScoreMatch> nextScores = getMatchingScoresOfNormalizedMatrix(
      next,
      supportedCharacters,
    );
    if (nextScores.isEmpty) {
      return false;
    }

    final Artifact merged = Artifact.fromMatrix(current);
    merged.mergeArtifact(next);

    final List<ScoreMatch> mergedScores = getMatchingScoresOfNormalizedMatrix(
      merged,
      supportedCharacters,
    );
    if (mergedScores.isEmpty) {
      return false;
    }

    final ScoreMatch bestMergedMatch = mergedScores.first;
    final double bestMerged = bestMergedMatch.score;
    final double bestIndividual = currentScore > nextScores.first.score
        ? currentScore
        : nextScores.first.score;

    if (bestMerged < _mergeScoreThreshold) {
      return false;
    }

    if ((bestMerged - bestIndividual) < _mergeScoreDelta) {
      return false;
    }

    band.artifacts[index] = merged;
    band.artifacts.removeAt(index + 1);
    return true;
  }

  /// Finds which character templates best match the given artifact.
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

    final Map<String, double> structuralMatchByCharacter = {};
    final List<CharacterDefinition> qualifiedTemplates =
        <CharacterDefinition>[];
    for (final CharacterDefinition template
        in characterDefinitions.definitions) {
      if (supportedCharacters.isNotEmpty &&
          !supportedCharacters.contains(template.character)) {
        continue;
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
      if (matchPercentage < percentageNeeded) {
        continue;
      }

      qualifiedTemplates.add(template);
      structuralMatchByCharacter[template.character] = matchPercentage;
    }

    final Artifact resizedArtifact = artifact.createNormalizeMatrix(
      templateWidth,
      templateHeight,
    );

    final IntRect content = artifact.getContentRect();
    final double inputAspectRatio = content.isEmpty
        ? 1.0
        : content.width / content.height;

    final List<ScoreMatch> scores = _getDistanceScores(
      qualifiedTemplates,
      resizedArtifact,
    );

    scores.sort((a, b) => b.score.compareTo(a.score));
    _applyStructuralTieBreak(scores, structuralMatchByCharacter);
    _promoteLetterOverPunctuation(scores);
    if (resizedArtifact.hasLowerRightStroke()) {
      _promoteRWhenLowerRightStroke(scores);
    }
    _promoteUWhenNarrowLowercaseM(
      scores,
      inputAspectRatio,
      resizedArtifact.countVerticalStems(),
    );
    return scores;
  }

  /// Resolves near-ties by preferring candidates with stronger structure matches.
  ///
  /// This helps disambiguate lookalikes such as `B` vs `D` when pixel distance
  /// is very close but one candidate better matches enclosure/line features.
  static void _applyStructuralTieBreak(
    List<ScoreMatch> scores,
    Map<String, double> structuralMatchByCharacter,
  ) {
    if (scores.length < _minimumTieBreakCandidates) {
      return;
    }

    final double bestScore = scores.first.score;
    final int topCategory = _characterCategory(scores.first.character);
    final bool topIsUppercase = isUppercaseLetter(scores.first.character);
    final bool topIsLowercase = isLowercaseLetter(scores.first.character);
    int bestIndex = 0;
    double bestStructural =
        structuralMatchByCharacter[scores.first.character] ?? 0;

    for (int i = 1; i < scores.length; i++) {
      final ScoreMatch candidate = scores[i];
      if ((bestScore - candidate.score) > _structuralTieBreakDelta) {
        break;
      }

      final int category = _characterCategory(candidate.character);
      if (category != topCategory) {
        continue;
      }
      if (category == _characterCategoryLetter &&
          !_matchesLetterCase(
            candidate.character,
            topIsUppercase,
            topIsLowercase,
          )) {
        continue;
      }

      final double structural =
          structuralMatchByCharacter[candidate.character] ?? 0;
      final bool strongerStructural =
          structural > (bestStructural + _scoreEqualityTolerance);
      final bool sameStructuralBetterScore =
          (structural - bestStructural).abs() <= _scoreEqualityTolerance &&
          candidate.score > scores[bestIndex].score;
      if (strongerStructural || sameStructuralBetterScore) {
        bestIndex = i;
        bestStructural = structural;
      }
    }

    if (bestIndex == 0) {
      return;
    }

    final ScoreMatch selected = scores.removeAt(bestIndex);
    scores.insert(0, selected);
  }

  /// Returns true when candidate letter casing is compatible with top score.
  static bool _matchesLetterCase(
    String candidate,
    bool topIsUppercase,
    bool topIsLowercase,
  ) {
    if (topIsUppercase) {
      return isUppercaseLetter(candidate);
    }
    if (topIsLowercase) {
      return isLowercaseLetter(candidate);
    }
    return true;
  }

  /// Classifies recognized candidates into broad groups for tie-break safety.
  static int _characterCategory(String character) {
    if (isLetter(character)) {
      return _characterCategoryLetter;
    }
    if (isDigit(character)) {
      return _characterCategoryDigit;
    }
    return _characterCategoryOther;
  }

  /// Prefers `R/r` over `P/p` when a lower-right stroke is detected.
  static void _promoteRWhenLowerRightStroke(List<ScoreMatch> scores) {
    if (scores.isEmpty) {
      return;
    }

    final int pIndex = scores.indexWhere(
      (score) => score.character == 'P' || score.character == 'p',
    );
    final int rIndex = scores.indexWhere(
      (score) => score.character == 'R' || score.character == 'r',
    );

    if (pIndex != 0 || rIndex < 0) {
      return;
    }

    final double pScore = scores[pIndex].score;
    final double rScore = scores[rIndex].score;
    if ((pScore - rScore) <= _lowerRightStrokeSwapDelta) {
      final ScoreMatch r = scores.removeAt(rIndex);
      scores.insert(0, r);
    }
  }

  /// Prefers `u` when a narrow lowercase `m` candidate is likely over-segmented.
  static void _promoteUWhenNarrowLowercaseM(
    List<ScoreMatch> scores,
    double inputAspectRatio,
    int stemCount,
  ) {
    if (scores.isEmpty) {
      return;
    }

    final int mIndex = scores.indexWhere((score) => score.character == 'm');
    final int uIndex = scores.indexWhere((score) => score.character == 'u');

    if (mIndex != 0 || uIndex < 0) {
      return;
    }

    if (stemCount <= _lowercaseMToUStemThreshold) {
      final ScoreMatch u = scores.removeAt(uIndex);
      scores.insert(0, u);
      return;
    }

    if (inputAspectRatio >= _lowercaseMToUAspectRatioThreshold) {
      return;
    }

    final double mScore = scores[mIndex].score;
    final double uScore = scores[uIndex].score;
    if ((mScore - uScore) <= _lowercaseMUScoreDelta) {
      final ScoreMatch u = scores.removeAt(uIndex);
      scores.insert(0, u);
    }
  }

  /// Prefers a letter over punctuation/symbol when scores are close.
  ///
  /// Text images overwhelmingly contain letters. When a bracket or symbol
  /// wins by a tiny margin over a letter with matching structural features,
  /// the letter is almost always the correct reading.
  static void _promoteLetterOverPunctuation(List<ScoreMatch> scores) {
    if (scores.length < _minimumTieBreakCandidates) {
      return;
    }

    final ScoreMatch top = scores.first;
    if (isLetter(top.character) || isDigit(top.character)) {
      return;
    }

    // Top is punctuation/symbol — look for a close letter alternative
    for (int i = 1; i < scores.length; i++) {
      final ScoreMatch candidate = scores[i];
      if ((top.score - candidate.score) > _letterOverPunctuationDelta) {
        break;
      }
      if (isLetter(candidate.character)) {
        final ScoreMatch letter = scores.removeAt(i);
        scores.insert(0, letter);
        return;
      }
    }
  }

  /// Re-evaluates punctuation/symbol matches when surrounded by letters.
  ///
  /// When a band is dominated by letter characters, isolated punctuation
  /// matches are likely OCR misreads. This pass re-scores those artifacts
  /// and promotes the best letter alternative if one exists.
  void _refinePunctuationInLetterContext(Band band) {
    final List<Artifact> artifacts = band.artifacts;
    if (artifacts.length < _minimumTieBreakCandidates) {
      return;
    }

    // Count how many matched characters are letters
    int letterCount = 0;
    for (final Artifact a in artifacts) {
      if (isLetter(a.matchingCharacter)) {
        letterCount++;
      }
    }

    // Only act when band is predominantly letters
    if (letterCount < artifacts.length * _letterDominanceRatio) {
      return;
    }

    for (int i = 0; i < artifacts.length; i++) {
      final Artifact artifact = artifacts[i];
      if (isLetter(artifact.matchingCharacter) ||
          isDigit(artifact.matchingCharacter) ||
          artifact.matchingCharacter == ' ' ||
          _isVerticalStrokeChar(artifact.matchingCharacter)) {
        continue;
      }

      // Check if neighbors are letters
      final bool leftIsLetter =
          i > 0 && isLetter(artifacts[i - 1].matchingCharacter);
      final bool rightIsLetter =
          i < artifacts.length - 1 &&
          isLetter(artifacts[i + 1].matchingCharacter);
      if (!leftIsLetter && !rightIsLetter) {
        continue;
      }

      // Re-score and pick best letter only if competitive with original
      final double originalScore = artifact.matchingScore;
      final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
        artifact,
      );
      for (final ScoreMatch score in scores) {
        if (isLetter(score.character) &&
            (originalScore - score.score) <= _bandContextPromotionDelta) {
          artifact.matchingCharacter = score.character;
          artifact.matchingScore = score.score;
          break;
        }
      }
    }
  }

  /// Re-merges consecutive narrow vertical-stroke artifacts (e.g. two 'I's)
  /// that may be halves of a split character like 'H'.
  ///
  /// After matching, two narrow artifacts both scoring as 'I' may actually
  /// be a single character whose crossbar was too faint to connect them.
  /// This pass tries merging each pair and accepts if the merged score
  /// is better than either individual.
  void _reMergeConsecutiveVerticalStrokes(Band band) {
    final int avgWidth = band.averageWidth;
    if (avgWidth <= 0) {
      return;
    }

    for (int i = 0; i < band.artifacts.length - 1; i++) {
      final Artifact current = band.artifacts[i];
      final Artifact next = band.artifacts[i + 1];

      if (!_isVerticalStrokeChar(current.matchingCharacter) ||
          !_isVerticalStrokeChar(next.matchingCharacter)) {
        continue;
      }

      // Both must be narrow relative to the band average
      if (current.rectFound.width > avgWidth * _mergeNarrowWidthRatio ||
          next.rectFound.width > avgWidth * _mergeNarrowWidthRatio) {
        continue;
      }

      // Gap must be reasonable
      final int gap = next.rectFound.left - current.rectFound.right;
      if (gap < 0 || gap > avgWidth ~/ _mergeGapWidthDivisor) {
        continue;
      }

      final Artifact merged = Artifact.fromMatrix(current);
      merged.mergeArtifact(next);

      final List<ScoreMatch> mergedScores = getMatchingScoresOfNormalizedMatrix(
        merged,
      );
      if (mergedScores.isEmpty ||
          mergedScores.first.score < _mergeScoreThreshold) {
        continue;
      }

      // Only accept if the merged result is a different character
      if (mergedScores.first.character == 'I') {
        continue;
      }

      // Accept the merge
      merged.matchingCharacter = mergedScores.first.character;
      merged.matchingScore = mergedScores.first.score;
      band.artifacts[i] = merged;
      band.artifacts.removeAt(i + 1);
      i--; // Re-check from same position
    }
  }

  /// Whether a character is a vertical-stroke glyph (I, l, |, 1) that could
  /// be half of a split two-stroke character like 'H'.
  static bool _isVerticalStrokeChar(String ch) =>
      ch == 'I' || ch == 'l' || ch == '|' || ch == '1' || ch == ']';

  /// Returns true only if splitting an artifact into [parts] produces a mean
  /// score strictly better than [originalScore].
  ///
  /// This prevents the split cascade where a low-scoring character is broken
  /// into several fragments that each score even lower.
  bool _splitImprovesScore(
    List<Artifact> parts,
    double originalScore,
    String supportedCharacters,
  ) {
    double total = 0;
    for (final Artifact part in parts) {
      final List<ScoreMatch> s = getMatchingScoresOfNormalizedMatrix(
        part,
        supportedCharacters,
      );
      total += s.isEmpty ? 0 : s.first.score;
    }
    return (total / parts.length) > originalScore;
  }

  /// Promotes lowercase-matched artifacts to their uppercase equivalent when
  /// the band is predominantly uppercase.
  ///
  /// Arial and similar fonts have uppercase/lowercase glyphs that look nearly
  /// identical at small sizes. If ≥ [_uppercaseDominanceRatio] of letter
  /// matches in a band are uppercase, re-score any lowercase artifacts and
  /// accept the uppercase alternative when the score gap is within
  /// [_bandContextPromotionDelta].
  void _refineUppercaseInUppercaseContext(Band band) {
    final List<Artifact> artifacts = band.artifacts;
    if (artifacts.length < _minimumTieBreakCandidates) {
      return;
    }

    int upperCount = 0;
    int letterCount = 0;
    for (final Artifact a in artifacts) {
      if (isUppercaseLetter(a.matchingCharacter)) {
        upperCount++;
        letterCount++;
      } else if (isLowercaseLetter(a.matchingCharacter)) {
        letterCount++;
      }
    }

    if (letterCount == 0) {
      return;
    }
    if (upperCount / letterCount < _uppercaseDominanceRatio) {
      return;
    }

    for (final Artifact artifact in artifacts) {
      if (!isLowercaseLetter(artifact.matchingCharacter)) {
        continue;
      }

      final double originalScore = artifact.matchingScore;
      final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
        artifact,
      );
      for (final ScoreMatch score in scores) {
        if (isUppercaseLetter(score.character) &&
            (originalScore - score.score) <= _bandContextPromotionDelta) {
          artifact.matchingCharacter = score.character;
          artifact.matchingScore = score.score;
          break;
        }
      }
    }
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

/// Internal helper for histogram-based candidate ranking.
class _HistogramRankedCandidate {
  const _HistogramRankedCandidate({
    required this.index,
    required this.histScore,
  });

  /// Index into the qualified templates list.
  final int index;

  /// Histogram similarity score (0.0 to 1.0).
  final double histScore;
}
