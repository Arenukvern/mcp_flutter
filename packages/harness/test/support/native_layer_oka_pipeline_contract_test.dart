@TestOn('vm')
library;

import 'dart:io';

import 'package:oka_android/oka_android.dart';
import 'package:test/test.dart';

import 'native_layer_evidence.dart';

void main() {
  group('oka pipeline contract (consumer)', () {
    final defaultNames =
        AndroidPipeline.defaultSteps.map((s) => s.name).toList();

    test('AndroidPipeline.defaultSteps includes record-run-session after packaging',
        () {
      final pkg = defaultNames.indexOf('package-and-sign');
      final record = defaultNames.indexOf('record-run-session');
      final lint = defaultNames.indexOf('post-build-lint');
      expect(pkg, greaterThanOrEqualTo(0));
      expect(record, greaterThan(pkg));
      expect(lint, greaterThan(record));
    });

    test('defaultApkPipeline includes record-run-session after packaging', () async {
      final pipeline = await defaultApkPipeline(
        ResolvedToolchain(),
        verbose: false,
        allowNetwork: false,
      );
      final names = pipeline.steps.map((s) => s.name).toList();
      final pkg = names.indexOf('package-and-sign');
      final record = names.indexOf('record-run-session');
      final lint = names.indexOf('post-build-lint');
      expect(pkg, greaterThanOrEqualTo(0));
      expect(record, greaterThan(pkg));
      expect(lint, greaterThan(record));
    });

    test('fixture oka_pipeline does not double-append RecordRunSessionStep', () {
      final repo = harnessRepoRoot();
      final hook = File(
        '${nativeCaptureFixtureApp(repo).path}/tool/oka_pipeline.dart',
      );
      expect(hook.existsSync(), isTrue);
      final src = hook.readAsStringSync();
      expect(src, contains('...AndroidPipeline.defaultSteps'));
      expect(
        src,
        isNot(contains('RecordRunSessionStep()')),
        reason:
            'pinned SDK defaultSteps already records session; explicit step '
            'would double-write',
      );
    });
  });
}
