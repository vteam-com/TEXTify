// ignore: fcheck_one_class_per_file
/// Shared string constants used across the Textify package.
library;

/// String constants for character description labels.
class CharacterLabels {
  static const String upperCase = 'Upper case';
  static const String lowerCase = 'Lower case';
  static const String digit = 'Digit';
}

/// String constants for configuration validation messages.
class ConfigErrors {
  static const String dilationPositive = 'dilationSize must be positive';
  static const String thresholdRange =
      'matchingThreshold must be between 0.0 and 1.0';
  static const String processingTimePositive =
      'maxProcessingTimeMs must be positive';
}

/// String constants for runtime assertions.
class TextifyErrors {
  static const String noCharacterDefinitions =
      'No character definitions loaded, did you forget to call Init()';
}

/// String constants for OCR post-processing corrections.
class OcrTokens {
  static const String upperI = 'I';
  static const String lowerL = 'l';
  static const String isToken = 'IS';
  static const String theEnd = 'TheEnd';
  static const String prefixT = 'T';
}
