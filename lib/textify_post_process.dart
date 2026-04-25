/// This library is part of the Textify package.
/// Provides post-processing normalization passes for OCR text output.
library;

import 'package:textify/post_process_bracket.dart';
import 'package:textify/post_process_case.dart';
import 'package:textify/post_process_dictionary.dart';
import 'package:textify/post_process_fragment.dart';
import 'package:textify/post_process_line.dart';
import 'package:textify/post_process_numeric.dart';
import 'package:textify/post_process_text.dart';

/// Applies final normalization passes to OCR text output.
String postProcessText(String text, {bool applyDictionary = true}) {
  if (text.isEmpty) {
    return text;
  }

  final List<String> lines = text.split('\n');
  final List<String> processed = <String>[];
  for (final String line in lines) {
    String value = resolveILAmbiguity(line);
    value = normalizeWordCaseCoherence(value);
    value = normalizeLineCase(value);
    value = normalizeNameLikeLineTitleCase(value);
    value = normalizeNumericGaps(value);
    value = normalizeDigitSegments(value);
    value = normalizeDateSeparators(value);
    value = normalizeBracketAsLetterNoise(value);
    value = normalizeFragmentedLine(value, applyDictionary: applyDictionary);
    if (applyDictionary) {
      value = correctNearMissDictionaryWords(value);
    }
    processed.add(value);
  }

  final List<String> merged = mergeNoiseLines(processed);
  final List<String> shortNoisyFixed = normalizeShortNoisyLines(merged);
  final String joined = shortNoisyFixed.join('\n');
  final String normalized = normalizePunctuationHeavyText(joined);
  final String lettersFixed = normalizeLetterConfusions(normalized);
  return normalizePunctuationSpacing(lettersFixed);
}
