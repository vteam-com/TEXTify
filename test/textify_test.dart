import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textify/character_definition.dart';
import 'package:textify/correction.dart';

import 'package:textify/textify.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Textify instance = await Textify().init(
    pathToAssetsDefinition: 'assets/matrices.json',
  );

  final List<String> supportedCharacters =
      instance.characterDefinitions.supportedCharacters;

  test('Character Definitions', () async {
    expect(instance.characterDefinitions.count, 90);

    expect(
      supportedCharacters.join(),
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,?!:;\'"(){}[]<>-/\\+=#\$&*@',
    );
  });

  test('Character Definitions Enclosures', () async {
    const String charactersWithEnclosures = '04689ABDOPQRabdegopq#@&\$';

    List<String> charactersWithNoEnclosures = supportedCharacters
        .where((c) => !charactersWithEnclosures.contains(c))
        .toList();

    // No englosure;
    for (final String char in charactersWithNoEnclosures) {
      final String reason = 'Characer > "$char"';
      final CharacterDefinition? definition =
          instance.characterDefinitions.getDefinition(char);

      expect(
        definition,
        isNotNull,
        reason: reason,
      );

      expect(
        instance.characterDefinitions.getDefinition(char)!.enclosures,
        0,
        reason: reason,
      );
    }

    // Enclosures
    expect(instance.characterDefinitions.getDefinition('A')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('B')!.enclosures, 2);
    expect(instance.characterDefinitions.getDefinition('D')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('O')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('P')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('Q')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('a')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('b')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('d')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('e')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('g')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('o')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('p')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('q')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('0')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('4')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('6')!.enclosures, 1);
    expect(instance.characterDefinitions.getDefinition('8')!.enclosures, 2);
    expect(instance.characterDefinitions.getDefinition('9')!.enclosures, 1);
  });

  test('Character Definitions Lines Left', () async {
    expect(instance.characterDefinitions.getDefinition('B')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('D')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('E')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('F')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('H')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('I')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('J')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('K')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('L')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('M')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('N')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('P')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('R')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('T')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('U')!.lineLeft, true);

    expect(instance.characterDefinitions.getDefinition('b')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('h')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('i')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('k')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('l')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('m')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('n')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('p')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('r')!.lineLeft, true);
    expect(instance.characterDefinitions.getDefinition('u')!.lineLeft, true);

    expect(instance.characterDefinitions.getDefinition('f')!.lineLeft, false);
    expect(instance.characterDefinitions.getDefinition('t')!.lineLeft, false);
  });

  test('Character Definitions Lines Right', () async {
    expect(instance.characterDefinitions.getDefinition('H')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('I')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('J')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('L')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('M')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('N')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('T')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('U')!.lineRight, true);

    expect(instance.characterDefinitions.getDefinition('d')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('i')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('j')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('l')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('m')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('n')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('q')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('t')!.lineRight, true);
    expect(instance.characterDefinitions.getDefinition('u')!.lineRight, true);
  });

  test('Convert image to text', () async {
    final ui.Image uiImage =
        await loadImageFromAssets('assets/test/input_test_image.png');
    final String text = await instance.getTextFromImage(image: uiImage);

    // the result are not perfect 90% accuracy, but its trending in the right direction
    expect(text, 'ABCDEFGHl\nJKLMN0PQR\nSTUVWxYZ\n01\n23456789');
    // errors here        ^       ^          ^
  });

  test('Convert image quick_brown_fox.png to text', () async {
    final ui.Image uiImage =
        await loadImageFromAssets('assets/test/quick_brown_fox.png');
    final String text = await instance.getTextFromImage(image: uiImage);

    // the result are not perfect 90% accuracy, but its trending in the right direction
    expect(text, '0 The QUiCk\nBr0Wn F0x\n1 23.45');
  });

  test('Dictionary Correction', () async {
    await myExpectWord('', '');
    await myExpectWord('Hell0', 'Hello');
    await myExpectWord('B0rder', 'Border');
    await myExpectWord('Hello W0rld', 'Hello world');
    await myExpectWord('ls', 'Is');
    await myExpectWord('lS', 'IS');
    await myExpectWord('ln', 'In');
    await myExpectWord('lN', 'IN');
    await myExpectWord('Date', 'Date');
    await myExpectWord('D@te', 'Date');
    await myExpectWord('D@tes', 'Dates');
    await myExpectWord('Bathr0Om', 'Bathroom');
    await myExpectWord('5pecial Ca5e', 'Special case');
  });

  test('Digit Correction', () async {
    expect(digitCorrection(''), '');
    expect(digitCorrection('0123456789'), '');
    expect(digitCorrection('O123456789'), '0123456789');
    expect(digitCorrection('ol23456789'), '0123456789');
  });
}

Future<void> myExpectWord(
  final String input,
  final String expected,
) async {
  expect(
    applyDictionaryCorrection(input),
    equals(expected),
    reason: 'INPUT WAS  "$input"',
  );
}
