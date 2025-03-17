import 'package:flutter/material.dart';
import 'package:textify/band.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/panel1_source/panel1_content.dart';
import 'package:textify_dashboard/panel3_results/panel3_toolbar.dart';
import 'package:textify_dashboard/settings.dart';
import 'package:textify_dashboard/widgets/gap.dart';
import 'edit.dart';
import 'matched_artifact.dart';

class PanelStep4Results extends StatefulWidget {
  const PanelStep4Results({
    super.key,
    required this.textify,
    required this.expectedStrings,
    required this.font,
    required this.settings,
    required this.onSettingsChanged,
  });

  final String font;
  final Textify textify;
  final List<String> expectedStrings;
  final Function onSettingsChanged;
  final Settings settings;

  @override
  State<PanelStep4Results> createState() => _PanelStep4ResultsState();
}

class _PanelStep4ResultsState extends State<PanelStep4Results> {
  @override
  Widget build(BuildContext context) {
    if (widget.expectedStrings.isEmpty) {
      return _buildFreeStyleResults(context);
    } else {
      return _buildMatchingCharacter(context);
    }
  }

  void onApplyDictionaryToggled(final bool onOff) async {
    widget.settings.applyDictionary = (onOff == true);
    await widget.settings.save();
    widget.textify.applyDictionary = widget.settings.applyDictionary;
    await widget.onSettingsChanged();

    setState(() {
      // update
    });
  }

  /// Builds a free-style results view for the `Textify` data, displaying the full text found in a selectable `Text` widget with a Courier font and blue cursor.
  Widget _buildFreeStyleResults(final BuildContext context) {
    return PanelStepContent(
      top: panelStep4toolbar(
        widget.settings.applyDictionary,
        onApplyDictionaryToggled,
      ),
      center: SizedBox(
        height: 300,
        child: SingleChildScrollView(
          child: SelectableText(
            widget.textify.textFound,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 16.0,
            ),
            showCursor: true,
            cursorColor: Colors.blue,
            cursorWidth: 2.0,
            cursorRadius: const Radius.circular(2.0),
          ),
        ),
      ),
    );
  }

  /// Builds a list of matched artifacts for each band in the `Textify` data.
  ///
  /// This method iterates through the bands and lines in the `Textify` data,
  /// and for each band, it builds a list of `MatchedArtifact` widgets that
  /// represent the characters in the current line and the expected characters.
  /// The resulting list of widgets is wrapped in a `SingleChildScrollView` and
  /// `Row` to allow horizontal scrolling.
  ///
  /// Parameters:
  /// - `context`: The `BuildContext` for the current widget.
  ///
  /// Returns:
  /// A `Widget` that displays the list of matched artifacts.
  Widget _buildListOfMatches(final BuildContext context) {
    final List<Widget> widgets = [];
    final List<String> stringsPerBand = widget.textify.textFound.split('\n');

    for (int lineIndex = 0;
        lineIndex < widget.textify.bands.length;
        lineIndex++) {
      // Band
      final Band band = widget.textify.bands.list[lineIndex];

      // Line
      final String currentLine =
          lineIndex < stringsPerBand.length ? stringsPerBand[lineIndex] : '';

      // Line expected
      final String expectedText = lineIndex < widget.expectedStrings.length
          ? widget.expectedStrings[lineIndex]
          : '';

      widgets.addAll(
        _buildArtifactsForBand(
          context: context,
          band: band,
          currentLine: currentLine,
          expectedText: expectedText,
        ),
      );

      widgets.add(gap());
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: widgets,
      ),
    );
  }

  /// Builds a list of `MatchedArtifact` widgets for the given band, current line,
  /// and expected text. Each `MatchedArtifact` widget represents a character in
  /// the current line and the expected character.
  ///
  /// The resulting list of widgets is returned, which can be used to display the
  /// matched artifacts for the given band.
  ///
  /// Parameters:
  /// - `context`: The `BuildContext` for the current widget.
  /// - `band`: The `Band` object containing the artifacts to be displayed.
  /// - `currentLine`: The current line of text being displayed.
  /// - `expectedText`: The expected text for the current line.
  ///
  /// Returns:
  /// A list of `MatchedArtifact` widgets representing the matched artifacts for
  /// the given band.
  List<Widget> _buildArtifactsForBand({
    required BuildContext context,
    required Band band,
    required String currentLine,
    required String expectedText,
  }) {
    return band.artifacts.asMap().entries.map((entry) {
      final int charIndex = entry.key;

      final Artifact artifact = entry.value;

      final String expectedCharacter =
          charIndex < expectedText.length ? expectedText[charIndex] : ' ';

      final String characterCorrected =
          charIndex < currentLine.length ? currentLine[charIndex] : '!';

      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditScreen(
                textify: widget.textify,
                artifact: artifact,
                characterExpected: expectedCharacter,
                characterFound: artifact.characterMatched,
              ),
            ),
          );
        },
        child: MatchedArtifact(
          characterFound: artifact.characterMatched,
          characterCorrected: characterCorrected,
          characterExpected: expectedCharacter,
          showCorrectionRow: widget.textify.applyDictionary,
        ),
      );
    }).toList();
  }

  /// Builds a widget that displays the matching characters for a given context.
  ///
  /// This method creates a `PanelContent` widget that contains a `Center` widget,
  /// which in turn contains a `Padding` widget with a `SizedBox` that has a
  /// `Row` with two children: the result of calling `_buildPrefixTextForMatches()`
  /// and the result of calling `_buildListOfMatches(context)`.
  ///
  /// Parameters:
  ///   - `context`: The `BuildContext` for the current widget.
  ///
  /// Returns:
  ///   A `Widget` that displays the matching characters for the given context.
  Widget _buildMatchingCharacter(final BuildContext context) {
    return PanelStepContent(
      top: panelStep4toolbar(
        widget.settings.applyDictionary,
        onApplyDictionaryToggled,
      ),
      center: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _buildPrefixTextForMatches(),
                Expanded(child: _buildListOfMatches(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a widget that displays the prefix text for the matched artifacts.
  ///
  /// This method creates a `Padding` widget that contains a `Column` with three
  /// `Text` widgets, one for each of the "Expected:", "Found:", and "Corrected:"
  /// labels.
  ///
  /// Returns:
  ///   A `Widget` that displays the prefix text for the matched artifacts.
  Widget _buildPrefixTextForMatches() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 10,
        children: [
          const Text('Found: '),
          if (widget.textify.applyDictionary) const Text('Corrected: '),
          const Text('Expected: '),
        ],
      ),
    );
  }
}

/// Compares two strings and returns their similarity as a percentage.
///
/// This function uses the Levenshtein distance algorithm to calculate the
/// edit distance between the two strings, and then converts it to a percentage
/// based on the maximum length of the strings.
///
/// If the two strings are identical, it returns 100.0. If either string is
/// empty, it returns 0.0.
///
/// Example usage:
///
/// ```dart
/// String s1 = "hello";
/// String s2 = "hallo";
/// double similarity = compareStringInPercentage(s1, s2);
/// print("Similarity: ${similarity.toStringAsFixed(2)}%"); // Output: Similarity: 80.00%
/// ```
///
/// Parameters:
///   s1: The first string to compare.
///   s2: The second string to compare.
///
/// Returns:
///   A double value representing the similarity percentage between the two
///   strings, clamped between 0.0 and 100.0.
double compareStringPercentage(String str1, String str2) {
  if (str1 == str2) {
    return 100.0;
  }
  if (str1.isEmpty || str2.isEmpty) {
    return 0.0;
  }

  int minLength = str1.length < str2.length ? str1.length : str2.length;
  int matchCount = 0;

  for (int i = 0; i < minLength; i++) {
    if (str1[i] == str2[i]) {
      matchCount++;
    }
  }

  return (matchCount / str1.length) * 100;
}
