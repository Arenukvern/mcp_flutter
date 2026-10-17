import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

void main() {
  group('parsePgrepPids', () {
    test('one pid per line, blanks skipped', () {
      expect(parsePgrepPids('123\n\n456\n'), <int>[123, 456]);
      expect(parsePgrepPids(''), isEmpty);
      expect(parsePgrepPids('not-a-pid\n'), isEmpty);
    });
  });

  group('parseLsofExecutablePath', () {
    test('returns the LAST n record (the executable, not the loader)', () {
      final out = 'p4242\nn/System/Library/dyld\nn'
          '/Users/me/app/build/Debug/foo.app/Contents/MacOS/foo\n';
      expect(
        parseLsofExecutablePath(out),
        '/Users/me/app/build/Debug/foo.app/Contents/MacOS/foo',
      );
    });

    test('null when no n records', () {
      expect(parseLsofExecutablePath('p4242\n'), isNull);
    });
  });

  group('parsePsLstart', () {
    test('parses the macOS lstart shape', () {
      expect(
        parsePsLstart('Thu Oct  6 21:04:33 2026\n'),
        DateTime(2026, 10, 6, 21, 4, 33),
      );
    });

    test('null on a foreign shape', () {
      expect(parsePsLstart(''), isNull);
      expect(parsePsLstart('started at noon'), isNull);
    });
  });

  group('buildNewerThanProcess', () {
    final started = DateTime(2026, 10, 6, 21, 0, 0);
    test('rebuilt after the process started → stale', () {
      expect(
        buildNewerThanProcess(
          binaryModified: started.add(const Duration(minutes: 2)),
          processStarted: started,
        ),
        isTrue,
      );
    });
    test('rebuilt just around the start (fs coarseness) → not stale', () {
      expect(
        buildNewerThanProcess(
          binaryModified: started.add(const Duration(seconds: 2)),
          processStarted: started,
        ),
        isFalse,
      );
    });
    test('binary older than the process → not stale', () {
      expect(
        buildNewerThanProcess(
          binaryModified: started.subtract(const Duration(hours: 1)),
          processStarted: started,
        ),
        isFalse,
      );
    });
  });

  group('BuildFingerprint', () {
    late Directory scratch;
    late String path;

    setUp(() async {
      scratch = await Directory.systemTemp.createTemp('fingerprint-test');
      path = '${scratch.path}/binary';
    });

    tearDown(() async {
      await scratch.delete(recursive: true);
    });

    test('fingerprints content; equality follows the build, not the clock',
        () async {
      File(path).writeAsStringSync('build v1');
      final first = await BuildFingerprint.of(path);

      expect(first.sameBuildAs(first), isTrue);
      expect(first, first);

      // Same content at a different path: same build, different identity.
      final copyPath = '${scratch.path}/binary-copy';
      File(copyPath).writeAsStringSync('build v1');
      final copy = await BuildFingerprint.of(copyPath);
      expect(copy.sameBuildAs(first), isTrue);
      expect(copy == first, isFalse);

      // Changed content → different build.
      File(path).writeAsStringSync('build v2');
      final second = await BuildFingerprint.of(path);
      expect(second.sameBuildAs(first), isFalse);
      expect(second == first, isFalse);
    });
  });

  group('BinaryAppTarget attach-only', () {
    test('without a VM service URI it fails naming the gap', () async {
      final target = BinaryAppTarget(
        projectDir: Directory.systemTemp.path,
        binaryPath: '/bin/true',
        ownership: AppOwnership.attachOnly,
      );
      await expectLater(target.launch(), throwsStateError);
    });

    test('with no matching running process it fails naming the search',
        () async {
      final target = BinaryAppTarget(
        projectDir: Directory.systemTemp.path,
        binaryPath: '/usr/bin/vosges-not-running-anywhere-8f3d1',
        ownership: AppOwnership.attachOnly,
        vmServiceUri: Uri.parse('http://127.0.0.1:1/'),
      );
      await expectLater(
        target.launch(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('attachOnly found no running'),
          ),
        ),
      );
    });

    test('a never-launched owned stop() still refuses the attached one',
        () async {
      // The core ownership law: an attached app is never signalled.
      final app = LaunchedApp.attached(
        name: 'borrowed',
        stdout: LogTap(),
        vmUri: Uri.parse('http://127.0.0.1:1/'),
      );
      expect(app.ownership, AppOwnership.attachOnly);
      expect(app.process, isNull);
      expect(await app.stop(), 0);
    });

    test('an owned app still stops its own process', () async {
      final process = await Process.start('sleep', <String>['10']);
      final owned = LaunchedApp(
        name: 'owned',
        process: process,
        stdout: LogTap(),
        vmUri: Uri.parse('http://127.0.0.1:1/'),
      );
      expect(owned.ownership, AppOwnership.launchAndOwn);
      final code = await owned.stop();
      expect(process.pid, isNotNull);
      // SIGTERM terminates sleep; the exit code comes back non-zero or
      // negative depending on the signal disposition — the point is it
      // DID exit without escalation.
      expect(code, isNot(equals(0)));
    });
  });
}
