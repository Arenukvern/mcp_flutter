import 'dart:convert';
import 'dart:io';

import 'package:universal_browser_cdp/universal_browser_cdp.dart';


/// Failure evidence, collected while the scenario runs and dumped as
/// one directory when a step fails.
///
/// The value is measured: a gate that failed on "Settings never opened"
/// was undiagnosable from the step error alone; the SAME run with a
/// console capture named the app-side exception immediately (a
/// DropdownButton assertion), and an AX dump distinguished "screen
/// didn't open" from "screen opened but the locator missed". Every
/// consumer re-rolled that plumbing by hand — it belongs to the
/// scenario.
///
/// ```dart
/// final evidence = EvidenceCollector();
/// evidence.attachApp('host', app.stdout);      // LogTap-style lines
/// evidence.attachCdp('peer', launchedWeb.page); // console + exceptions
/// final scenario = Scenario('gate', steps: steps, evidence: evidence);
/// ```
final class EvidenceCollector {
  final _buffers = <String, List<String>>{};
  final _files = <String, Future<File> Function(Directory dir)>{};

  /// Streams [lines] into a named buffer (app stdout/stderr taps).
  void attachLines(String name, Stream<String> lines) {
    _buffers.putIfAbsent(name, () => []);
    lines.listen(_buffers[name]!.add, cancelOnError: false);
  }

  /// Attaches a CDP page: buffers its console messages and uncaught
  /// exceptions (an app-side throw renders as a canvas error screen —
  /// invisible in the DOM — and only the console names it).
  void attachCdp(String name, CdpPage page) {
    _buffers.putIfAbsent(name, () => []);
    page.connection.on('Runtime.consoleAPICalled').listen((event) {
      final args = event.params['args'] as List<Object?>? ?? const [];
      _buffers[name]!.add([
        for (final arg in args)
          if (arg is Map<String, Object?>)
            (arg['value'] ?? arg['description'] ?? '').toString(),
      ].join(' '));
    });
    page.connection.on('Runtime.exceptionThrown').listen((event) {
      _buffers[name]!
          .add('[exception] ${const JsonEncoder().convert(event.params)}');
    });
  }

  /// Registers a lazily-produced file (an AX dump, a state JSON) written
  /// only when a dump happens.
  void attachFile(String name, Future<File> Function(Directory dir) produce) {
    _files[name] = produce;
  }

  /// Records a point-in-time value into a named buffer.
  void record(String name, Object? value) {
    _buffers.putIfAbsent(name, () => []).add(value.toString());
  }

  /// Writes everything into [directory] (created); returns its path.
  /// Buffer tails are capped (the first lines rarely matter; the last
  /// 200 do).
  Future<String> dump(Directory directory) async {
    await directory.create(recursive: true);
    for (final entry in _buffers.entries) {
      final lines = entry.value;
      final tail =
          lines.length <= 200 ? lines : lines.sublist(lines.length - 200);
      File('${directory.path}/${entry.key}.log').writeAsStringSync(
        tail.join('\n'),
        mode: FileMode.write,
      );
    }
    for (final entry in _files.entries) {
      try {
        await entry.value(directory);
      } on Object {
        // Evidence is best-effort by contract: a producer whose app is
        // already dead must not mask the real failure.
      }
    }
    return directory.path;
  }
}
