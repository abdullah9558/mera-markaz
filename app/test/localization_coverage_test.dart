import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/localization/urdu_phrases.dart';

void main() {
  test('presentation files do not contain direct literal Text widgets', () {
    final violations = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (file) =>
                  file.path.contains(
                    '${Platform.pathSeparator}presentation${Platform.pathSeparator}',
                  ) &&
                  file.path.endsWith('.dart'),
            )) {
      final source = file.readAsStringSync();
      final pattern = RegExp(r'''Text\(\s*(['"])(.*?)\1''', dotAll: true);
      for (final match in pattern.allMatches(source)) {
        final literal = match.group(2)!;
        if (!literal.contains(r'$') && literal != 'PakPocket') {
          violations.add('${file.path}: $literal');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Use AppLocalizations.text/phrase for every user-facing literal.',
    );
  });

  test('every literal phrase lookup has an Urdu translation', () {
    final missing = <String>{};
    final pattern = RegExp(
      r'''phrase\(\s*'([^']*)'\s*,?\s*\)''',
      multiLine: true,
    );
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final phrase = match.group(1)!;
        if (!urduPhrases.containsKey(phrase) &&
            !{'PakPocket', 'اردو', '•'}.contains(phrase)) {
          missing.add(phrase);
        }
      }
    }
    expect(missing, isEmpty, reason: 'Add every phrase to urduPhrases.');
  });
}
