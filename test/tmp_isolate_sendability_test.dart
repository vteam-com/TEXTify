import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/models/textify_config.dart';
import 'package:textify/textify.dart';

void main() {
  test('Textify object can be returned from Isolate.run', () async {
    final Artifact artifact = Artifact.fromAsciiDefinition([
      '#####',
      '#...#',
      '#...#',
      '#...#',
      '#####',
    ]);

    final Textify result = await Isolate.run(() async {
      final Textify worker = Textify(config: const TextifyConfig());
      worker.processBegin = DateTime.now();
      worker.processEnd = DateTime.now();
      worker.extractBandsAndArtifacts(artifact);
      worker.textFound = 'ok';
      return worker;
    });

    expect(result.textFound, equals('ok'));
    expect(result.bands.length, greaterThanOrEqualTo(0));
  });
}
