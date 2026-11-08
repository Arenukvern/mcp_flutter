@TestOn('vm')
library;

import 'dart:io';

import 'package:oka_android/oka_android.dart';
import 'package:test/test.dart';

import 'native_layer_evidence.dart';

void main() {
  group('oka 0.9.1 pipeline contract (consumer)', () {
    test('AndroidPipeline.defaultSteps omits record-run-session', () {
      final names = AndroidPipeline.defaultSteps.map((s) => s.name).toList();
      expect(names, contains('package-and-sign'));
      expect(names, contains('validate-layout'));
      expect(names, isNot(contains('record-run-session')));
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

    test('fixture oka_pipeline appends RecordRunSessionStep after defaultSteps', () {
      final repo = harnessRepoRoot();
      final hook = File(
        '${nativeCaptureFixtureApp(repo).path}/tool/oka_pipeline.dart',
      );
      expect(hook.existsSync(), isTrue);
      final src = hook.readAsStringSync();
      expect(src, contains('...AndroidPipeline.defaultSteps'));
      expect(src, contains('RecordRunSessionStep()'));
      final defaultIdx = src.indexOf('...AndroidPipeline.defaultSteps');
      final recordIdx = src.indexOf('RecordRunSessionStep()');
      expect(recordIdx, greaterThan(defaultIdx));
    });
  });
}
