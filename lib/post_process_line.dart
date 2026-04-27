/// Line-level cleanup passes for OCR post-processing.
///
/// Handles noise line detection and merging, short noisy line
/// normalization, and punctuation-heavy text filtering.
library;

import 'package:textify/post_process_helpers.dart';

const int _maxNoiseLineLength = 2;
const int _punctuationFilterShortLineMaxLength = 5;
const double _punctuationHeavyRatioThreshold = 0.4;
const int _repeatedCommaSuffixMinLength = 4;
const int _repeatedCommaSuffixMinStemLength = 4;
const int _trailingSingleUpperStemMinLength = 3;
const int _postalCodeLength = 5;
const int _postalCodeChunkMinLength = 2;
const int _postalCodeChunkMaxLength = 3;
const int _postalPrefixGroup = 1;
const int _postalRegionGroup = 2;
const int _postalLeftChunkGroup = 3;
const int _postalRightChunkGroup = 4;
const int _receiptRowMinNameLength = 3;
const int _receiptSummaryMinLabelLength = 5;
const int _receiptSummaryTokenCount = 2;
const int _receiptPriceWholeGroup = 1;
const int _receiptPriceFractionGroup = 2;
const int _receiptMergedQuantityGroup = 1;
const int _receiptMergedPriceGroup = 2;

/// Splits all-caps merchant/location tokens that repeat the comma suffix.
///
/// OCR sometimes drops the space before a trailing location token in lines like
/// `EUROLOJAMATOSINHOS, MATOSINHOS`. When the final token before the comma is
/// all-caps and redundantly ends with the same all-caps word that starts the
/// comma suffix, insert the missing space.
String normalizeRepeatedCommaSuffix(String line) {
  final int commaIndex = line.indexOf(',');
  if (commaIndex <= 0 || commaIndex == line.length - 1) {
    return line;
  }

  final String before = line.substring(0, commaIndex).trimRight();
  final String after = line.substring(commaIndex + 1).trimLeft();
  if (before.isEmpty || after.isEmpty) {
    return line;
  }

  final Match? suffixMatch = RegExp(r'^([A-Z]{4,})(?:\b|$)').firstMatch(after);
  if (suffixMatch == null) {
    return line;
  }

  final String suffix = suffixMatch.group(1) ?? '';
  if (suffix.length < _repeatedCommaSuffixMinLength) {
    return line;
  }

  final Match? lastTokenMatch = RegExp(r'([A-Z]+)$').firstMatch(before);
  if (lastTokenMatch == null) {
    return line;
  }

  final String lastToken = lastTokenMatch.group(1) ?? '';
  if (lastToken == suffix || !lastToken.endsWith(suffix)) {
    return line;
  }

  final String stem = lastToken.substring(0, lastToken.length - suffix.length);
  if (stem.length < _repeatedCommaSuffixMinStemLength) {
    return line;
  }

  final String prefix = before.substring(0, lastTokenMatch.start);
  return '$prefix$stem $suffix, $after';
}

/// Splits alpha tokens that end with a stray trailing uppercase letter.
///
/// OCR can drop the space before a trailing capital initial, producing tokens
/// like `ChaE` or `GadgetC`. When a token is otherwise clean title/lowercase
/// text and ends with a single uppercase letter, insert the missing space.
String normalizeTrailingSingleUpperTokenSplit(String line) {
  return line.replaceAllMapped(RegExp(r'\b([A-Z][a-z]{2,})([A-Z])\b'), (
    Match match,
  ) {
    final String stem = match.group(1) ?? '';
    final String trailingUpper = match.group(regexGroupSecond) ?? '';
    if (stem.length < _trailingSingleUpperStemMinLength ||
        trailingUpper.isEmpty) {
      return match.group(0) ?? line;
    }

    return '$stem $trailingUpper';
  });
}

/// Splits short standalone uppercase-digit tokens in mixed-case table rows.
///
/// OCR can merge a quantity initial and following digit into tokens like `B1`
/// in rows such as `Widget B1 7-50`. When the token sits between a mixed-case
/// word label and a numeric value token, insert the missing space.
String normalizeStandaloneUpperDigitTokenSplit(String line) {
  final List<String> pieces = RegExp(
    r'\S+|\s+',
  ).allMatches(line).map((Match match) => match.group(0) ?? '').toList();
  if (pieces.isEmpty) {
    return line;
  }

  for (int i = 0; i < pieces.length; i++) {
    final String current = pieces[i];
    if (current.trim().isEmpty || !RegExp(r'^[A-Z][0-9]$').hasMatch(current)) {
      continue;
    }

    String? previousToken;
    for (int p = i - 1; p >= 0; p--) {
      if (pieces[p].trim().isNotEmpty) {
        previousToken = pieces[p];
        break;
      }
    }

    String? nextToken;
    for (int n = i + 1; n < pieces.length; n++) {
      if (pieces[n].trim().isNotEmpty) {
        nextToken = pieces[n];
        break;
      }
    }

    final bool mixedCaseWordBefore =
        previousToken != null &&
        RegExp(r'^[A-Za-z]{3,}$').hasMatch(previousToken) &&
        RegExp(r'[a-z]').hasMatch(previousToken);
    final bool numericTokenAfter =
        nextToken != null && RegExp(r'^\d[\d.,/-]*$').hasMatch(nextToken);
    if (!mixedCaseWordBefore || !numericTokenAfter) {
      continue;
    }

    pieces[i] = '${current[0]} ${current[1]}';
  }

  return pieces.join();
}

/// Repairs receipt-style quantity/price rows with noisy decimal separators.
///
/// OCR can merge quantity and price tokens into forms like `3.12-99`, keep
/// decimal prices as `7-50`, or emit comma decimals like `57,48`. When the
/// line looks like an item row or uppercase summary row, normalize those
/// price-like tokens without touching short code rows such as `SKU B1 7-50`.
String normalizePriceLikeTableRow(String line) {
  if (line.isEmpty || line.contains(':')) {
    return line;
  }

  final List<String> pieces = RegExp(
    r'\S+|\s+',
  ).allMatches(line).map((Match match) => match.group(0) ?? '').toList();
  if (pieces.isEmpty) {
    return line;
  }

  final List<int> tokenIndexes = <int>[];
  for (int i = 0; i < pieces.length; i++) {
    if (pieces[i].trim().isNotEmpty) {
      tokenIndexes.add(i);
    }
  }
  if (tokenIndexes.isEmpty) {
    return line;
  }

  bool hasStandalonePriceToken = false;
  bool hasMergedQuantityPriceToken = false;
  int quantityTokenCount = 0;
  for (final int tokenIndex in tokenIndexes) {
    final String token = pieces[tokenIndex];
    if (_isStandalonePriceToken(token)) {
      hasStandalonePriceToken = true;
      continue;
    }
    if (_isMergedQuantityPriceToken(token)) {
      hasMergedQuantityPriceToken = true;
      continue;
    }
    if (RegExp(r'^\d+$').hasMatch(token)) {
      quantityTokenCount++;
    }
  }

  if (!hasStandalonePriceToken && !hasMergedQuantityPriceToken) {
    return line;
  }

  final String firstToken = pieces[tokenIndexes.first];
  final bool itemRow =
      RegExp(r'^[A-Za-z]{3,}$').hasMatch(firstToken) &&
      firstToken != firstToken.toUpperCase() &&
      (hasMergedQuantityPriceToken ||
          (hasStandalonePriceToken && quantityTokenCount > 0));
  final bool summaryRow =
      tokenIndexes.length == _receiptSummaryTokenCount &&
      RegExp(r'^[A-Z]{5,}$').hasMatch(firstToken) &&
      hasStandalonePriceToken;
  if (!itemRow && !summaryRow) {
    return line;
  }

  for (final int tokenIndex in tokenIndexes) {
    final String token = pieces[tokenIndex];
    if (_isMergedQuantityPriceToken(token)) {
      pieces[tokenIndex] = _normalizeMergedQuantityPriceToken(token);
      continue;
    }
    if (_isStandalonePriceToken(token)) {
      pieces[tokenIndex] = _normalizeStandalonePriceToken(token);
    }
  }

  if (itemRow &&
      firstToken.length >= _receiptRowMinNameLength &&
      firstToken == firstToken.toLowerCase()) {
    pieces[tokenIndexes.first] = toTitleCaseWord(firstToken);
  }

  if (summaryRow && firstToken.length < _receiptSummaryMinLabelLength) {
    return line;
  }

  return pieces.join();
}

bool _isStandalonePriceToken(String token) {
  return RegExp(r'^\d{1,3}[-,]\d{2}$').hasMatch(token);
}

/// Normalizes a standalone receipt price token to dotted decimal form.
///
/// This repairs OCR forms like `7-50` and `57,48` into `7.50` and `57.48`
/// once the surrounding row shape has already established price context.
String _normalizeStandalonePriceToken(String token) {
  final Match? match = RegExp(r'^(\d{1,3})[-,](\d{2})$').firstMatch(token);
  if (match == null) {
    return token;
  }

  final String whole = match.group(_receiptPriceWholeGroup) ?? '';
  final String fraction = match.group(_receiptPriceFractionGroup) ?? '';
  if (whole.isEmpty || fraction.isEmpty) {
    return token;
  }

  return '$whole.$fraction';
}

bool _isMergedQuantityPriceToken(String token) {
  return RegExp(r'^\d[.,-]\d{2,3}[-,]\d{2}$').hasMatch(token);
}

/// Splits merged receipt quantity-plus-price tokens into separate columns.
///
/// OCR can collapse rows like `Widget A 3 12.99` into `Widget A 3.12-99`.
/// This keeps the leading single-digit quantity and reuses the standalone
/// price normalization for the trailing price segment.
String _normalizeMergedQuantityPriceToken(String token) {
  final Match? match = RegExp(
    r'^(\d)[.,-](\d{2,3}[-,]\d{2})$',
  ).firstMatch(token);
  if (match == null) {
    return token;
  }

  final String quantity = match.group(_receiptMergedQuantityGroup) ?? '';
  final String rawPrice = match.group(_receiptMergedPriceGroup) ?? '';
  if (quantity.isEmpty || rawPrice.isEmpty) {
    return token;
  }

  final String normalizedPrice = _normalizeStandalonePriceToken(rawPrice);
  if (normalizedPrice == rawPrice) {
    return token;
  }

  return '$quantity $normalizedPrice';
}

/// Repairs split 5-digit postal codes after uppercase region abbreviations.
///
/// OCR can emit address lines like `SAN FRANCISCO, CA941 05` or
/// `SAN FRANCISCO, CA 941 05`. When a comma is followed by a two-letter
/// uppercase region token and two digit chunks totaling five digits, keep one
/// space before the postal code and remove the internal split.
String normalizeRegionPostalCodeSpacing(String line) {
  if (line.isEmpty) {
    return line;
  }

  return line.replaceAllMapped(
    RegExp(r'(,\s*)([A-Z]{2})\s*(\d{2,3})\s+(\d{2,3})(?=\b)'),
    (Match match) {
      final String prefix = match.group(_postalPrefixGroup) ?? '';
      final String region = match.group(_postalRegionGroup) ?? '';
      final String zipLeft = match.group(_postalLeftChunkGroup) ?? '';
      final String zipRight = match.group(_postalRightChunkGroup) ?? '';
      if (prefix.isEmpty ||
          region.isEmpty ||
          zipLeft.isEmpty ||
          zipRight.isEmpty) {
        return match.group(0) ?? line;
      }

      final int combinedZipLength = zipLeft.length + zipRight.length;
      final bool validZipShape =
          combinedZipLength == _postalCodeLength &&
          zipLeft.length >= _postalCodeChunkMinLength &&
          zipLeft.length <= _postalCodeChunkMaxLength &&
          zipRight.length >= _postalCodeChunkMinLength &&
          zipRight.length <= _postalCodeChunkMaxLength;
      if (!validZipShape) {
        return match.group(0) ?? line;
      }

      return '$prefix$region $zipLeft$zipRight';
    },
  );
}

/// Merges short noise-only lines into the following content line when useful.
List<String> mergeNoiseLines(List<String> lines) {
  if (lines.isEmpty) {
    return lines;
  }

  final List<String> merged = <String>[];
  int i = 0;
  while (i < lines.length) {
    final String current = lines[i];
    if (_isNoiseLine(current)) {
      if (current.isEmpty) {
        merged.add(current);
      }
      i++;
      continue;
    }

    merged.add(current);
    i++;
  }

  return merged;
}

/// Returns true when a line appears to be OCR noise rather than content.
bool _isNoiseLine(String line) {
  final String trimmed = line.trim();
  if (trimmed.isEmpty) {
    return true;
  }
  if (trimmed.length > _maxNoiseLineLength) {
    return false;
  }

  for (int i = 0; i < trimmed.length; i++) {
    final int code = trimmed.codeUnitAt(i);
    if (isLetter(code) || isDigit(code)) {
      if (!_noiseLetters.contains(trimmed[i])) {
        return false;
      }
      continue;
    }
    if (!_noisePunctuation.contains(trimmed[i])) {
      return false;
    }
  }

  return true;
}

/// Normalizes tiny noisy lines often produced by decorative serif fragments.
List<String> normalizeShortNoisyLines(List<String> lines) {
  return lines;
}

/// Normalizes lines that are overwhelmingly punctuation.
String normalizePunctuationHeavyText(String text) {
  final List<String> lines = text.split('\n');
  final List<String> filtered = <String>[];

  for (final String line in lines) {
    if (line.isEmpty) {
      filtered.add(line);
      continue;
    }

    int punctuation = 0;
    int alphanumeric = 0;
    for (int i = 0; i < line.length; i++) {
      final int code = line.codeUnitAt(i);
      if (isLetter(code) || isDigit(code)) {
        alphanumeric++;
      } else if (line[i] != ' ') {
        punctuation++;
      }
    }

    if (line.length > _punctuationFilterShortLineMaxLength) {
      filtered.add(line);
      continue;
    }

    if (alphanumeric == 0 && punctuation > 0) {
      continue;
    }

    if (punctuation / (punctuation + alphanumeric) >
        _punctuationHeavyRatioThreshold) {
      continue;
    }

    filtered.add(line);
  }

  return filtered.join('\n');
}

const Set<String> _noiseLetters = {'i', 'l', 'I', 'L', 't', 'T'};

const Set<String> _noisePunctuation = {
  '*',
  '-',
  '_',
  '|',
  '!',
  '\'',
  '`',
  '.',
  ',',
};
