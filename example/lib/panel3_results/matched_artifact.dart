import 'package:flutter/material.dart';

class MatchedArtifact extends StatelessWidget {
  const MatchedArtifact({
    super.key,
    required this.characterFound,
    required this.characterCorrected,
    required this.characterExpected,
    required this.showCorrectionRow,
  });

  final String characterFound;
  final String characterCorrected;
  final String characterExpected;
  final bool showCorrectionRow;

  @override
  Widget build(BuildContext context) {
    const TextStyle style = TextStyle(
      fontSize: 20,
      fontFamily: 'Courier',
    );

    final TextStyle styleExpected = style.copyWith(color: Colors.white);

    final TextStyle styleMatching =
        style.copyWith(color: Colors.lightGreen.shade400);

    final TextStyle styleNoMatch = style.copyWith(color: Colors.red);

    final TextStyle styleCorrected = style.copyWith(color: Colors.orange);

    final String endResultChar =
        showCorrectionRow ? characterCorrected : characterFound;

    return Container(
      margin: const EdgeInsets.all(1),
      width: 18,
      decoration: BoxDecoration(
        border: Border.all(
          color: characterExpected == endResultChar
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.5),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 6,
        children: [
          // As Found
          Text(
            characterFound,
            style: characterExpected == characterFound
                ? styleMatching
                : styleNoMatch,
          ),
          if (showCorrectionRow)
            // Spell checked
            Text(
              characterCorrected,
              style: characterExpected == characterFound
                  ? styleMatching
                  : styleCorrected,
            ),
          // Expected vs final result
          Text(
            characterExpected,
            style: characterExpected == endResultChar
                ? styleExpected
                : styleNoMatch,
          ),
        ],
      ),
    );
  }
}
