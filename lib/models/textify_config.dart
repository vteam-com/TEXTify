/// Configuration options for Textify OCR processing.
///
/// This class provides customizable settings that control various aspects
/// of the OCR process including image preprocessing, character recognition,
/// and performance tuning.
class TextifyConfig {
  /// Size of the dilation kernel used in preprocessing.
  ///
  /// Controls how much nearby pixels are merged together. Larger values help
  /// connect broken characters but may merge unrelated elements.
  /// Default: 22
  final int dilationSize;

  /// Whether to exclude long horizontal and vertical lines from text recognition.
  ///
  /// When true, lines that span a significant portion of the image are ignored
  /// to avoid false positives. Default: true
  final bool excludeLongLines;

  /// Whether to attempt splitting touching characters.
  ///
  /// When true, the system tries to separate characters that are connected.
  /// This improves accuracy for some fonts but adds processing time. Default: true
  final bool attemptCharacterSplitting;

  /// Whether to apply dictionary-based text correction.
  ///
  /// When enabled, recognized text is compared against a dictionary
  /// to improve accuracy by correcting likely mis-recognitions. Default: false
  final bool applyDictionaryCorrection;

  /// Minimum similarity score required for character matching.
  ///
  /// Values closer to 1.0 require higher confidence matches but may miss
  /// some correct characters. Values closer to 0.0 may include more false
  /// positives. Default: 0.4
  final double matchingThreshold;

  /// Maximum processing time in milliseconds.
  ///
  /// Limits how long the OCR process can take before timing out.
  /// Default: 30000 (30 seconds)
  final int maxProcessingTimeMs;

  /// Creates a Textify configuration with the specified options.
  const TextifyConfig({
    this.dilationSize = 22,
    this.excludeLongLines = true,
    this.attemptCharacterSplitting = true,
    this.applyDictionaryCorrection = false,
    this.matchingThreshold = 0.4,
    this.maxProcessingTimeMs = 30000,
  }) : assert(dilationSize > 0, 'dilationSize must be positive'),
       assert(
         matchingThreshold >= 0.0 && matchingThreshold <= 1.0,
         'matchingThreshold must be between 0.0 and 1.0',
       ),
       assert(maxProcessingTimeMs > 0, 'maxProcessingTimeMs must be positive');

  /// Fast configuration optimized for speed.
  ///
  /// Uses smaller dilation, disables line exclusion and character splitting
  /// for quicker processing at the cost of some accuracy.
  static const TextifyConfig fast = TextifyConfig(
    dilationSize: 15,
    excludeLongLines: false,
    attemptCharacterSplitting: false,
    applyDictionaryCorrection: false,
    matchingThreshold: 0.3,
  );

  /// Accurate configuration optimized for precision.
  ///
  /// Uses larger dilation, enables dictionary correction, and higher
  /// matching threshold for better accuracy at the cost of speed.
  static const TextifyConfig accurate = TextifyConfig(
    dilationSize: 30,
    excludeLongLines: true,
    attemptCharacterSplitting: true,
    applyDictionaryCorrection: true,
    matchingThreshold: 0.6,
  );

  /// Robust configuration for challenging images.
  ///
  /// Uses aggressive dilation and character splitting with dictionary
  /// correction for handling low-quality or noisy images.
  static const TextifyConfig robust = TextifyConfig(
    dilationSize: 35,
    excludeLongLines: true,
    attemptCharacterSplitting: true,
    applyDictionaryCorrection: true,
    matchingThreshold: 0.5,
  );

  /// Balanced configuration with default settings.
  ///
  /// Provides a good balance between speed and accuracy for most use cases.
  static const TextifyConfig balanced = TextifyConfig();

  @override
  String toString() {
    return 'TextifyConfig('
        'dilationSize: $dilationSize, '
        'excludeLongLines: $excludeLongLines, '
        'attemptCharacterSplitting: $attemptCharacterSplitting, '
        'applyDictionaryCorrection: $applyDictionaryCorrection, '
        'matchingThreshold: $matchingThreshold, '
        'maxProcessingTimeMs: $maxProcessingTimeMs)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TextifyConfig &&
        other.dilationSize == dilationSize &&
        other.excludeLongLines == excludeLongLines &&
        other.attemptCharacterSplitting == attemptCharacterSplitting &&
        other.applyDictionaryCorrection == applyDictionaryCorrection &&
        other.matchingThreshold == matchingThreshold &&
        other.maxProcessingTimeMs == maxProcessingTimeMs;
  }

  @override
  int get hashCode {
    return Object.hash(
      dilationSize,
      excludeLongLines,
      attemptCharacterSplitting,
      applyDictionaryCorrection,
      matchingThreshold,
      maxProcessingTimeMs,
    );
  }

  /// Creates a copy of this TextifyConfig with the given fields replaced.
  TextifyConfig copyWith({
    int? dilationSize,
    bool? excludeLongLines,
    bool? attemptCharacterSplitting,
    bool? applyDictionaryCorrection,
    double? matchingThreshold,
    int? maxProcessingTimeMs,
  }) {
    return TextifyConfig(
      dilationSize: dilationSize ?? this.dilationSize,
      excludeLongLines: excludeLongLines ?? this.excludeLongLines,
      attemptCharacterSplitting:
          attemptCharacterSplitting ?? this.attemptCharacterSplitting,
      applyDictionaryCorrection:
          applyDictionaryCorrection ?? this.applyDictionaryCorrection,
      matchingThreshold: matchingThreshold ?? this.matchingThreshold,
      maxProcessingTimeMs: maxProcessingTimeMs ?? this.maxProcessingTimeMs,
    );
  }
}
