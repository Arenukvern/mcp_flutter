import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Drives the LA automations editor end to end through the real UI:
/// stage=open  -> + button, fill the form, save, verify the new row
/// stage=edit  -> tap a row, change the schedule, save, verify
/// stage=delete-> tap a row, delete, confirm, verify gone
Future<void> main(List<String> args) async {
  final stage = args.isNotEmpty ? args.first : 'open';
  final out = args.length > 1 ? args[1] : '/tmp';
  final target = args.length > 2 ? args[2] : 'demo-timer';
  final vmUri = Platform.environment['LA_VM_URI']!;
  final client = await VmClient.connect(Uri.parse(vmUri));
  final driver = ToolkitDriver(client);
  Future<T> step<T>(String name, Future<T> Function() body) =>
      body().timeout(const Duration(seconds: 25), onTimeout: () {
        stderr.writeln('TIMEOUT at step: $name');
        exit(3);
      });
  Future<Map<String, dynamic>> ext(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
  }) =>
      step(name, () => client.callExtension(name, args: args));

  Future<List<Map<String, Object?>>> nodes({
    bool visibleOnly = false,
  }) async {
    final tree = await step('snapshot', () => ext(ToolkitExtensions.snapshot));
    return (tree['nodes']! as List<Object?>)
        .whereType<Map<String, Object?>>()
        .where((n) => !visibleOnly || n['visibleInViewport'] == true)
        .toList();
  }

  Future<Map<String, Object?>?> byLabel(
    List<Map<String, Object?>> ns,
    String label, {
    String? type,
  }) async =>
      ns
          .where(
            (n) =>
                '${n['label']}' == label &&
                (type == null || '${n['type']}'.contains(type)),
          )
          .firstOrNull;

  Future<void> tapRef(String ref) async {
    await step('tap-$ref', () {
      return ext(ToolkitExtensions.tap, args: {'ref': ref});
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  Future<void> typeInto(
    List<Map<String, Object?>> ns,
    String label,
    String text,
  ) async {
    final field = ns
        .where(
          (n) =>
              '${n['type']}'.toLowerCase().contains('textfield') &&
              '${n['label']}' == label,
        )
        .firstOrNull;
    if (field == null) {
      stderr.writeln('textfield "$label" not found');
      exit(2);
    }
    await step('enter-$label', () {
      return ext(
        ToolkitExtensions.enterText,
        args: {'ref': field['ref'], 'text': text},
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> scrollTo(String label) async {
    // Start from the top: the target may sit above the current scroll.
    await step('scroll-top', () {
      return ext(ToolkitExtensions.scroll,
          args: {'direction': 'up', 'distance': 8000});
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    for (var i = 0; i < 8; i++) {
      final ns = await nodes();
      final node = ns
          .where(
            (n) => '${n['label']}'.contains(label) &&
                n['visibleInViewport'] == true,
          )
          .firstOrNull;
      if (node != null) return;
      await step('scroll-$i', () {
        return ext(ToolkitExtensions.scroll,
            args: {'direction': 'down', 'distance': 900});
      });
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> shot(String name) async {
    final bytes = await step('shot-$name', () => driver.screenshot());
    await File('$out/la-editor-$name.png').writeAsBytes(bytes);
    stdout.writeln('shot: $out/la-editor-$name.png');
  }

  try {
    if (stage == 'open') {
      // A leftover open sheet would block navigation: cancel it.
      var ns0 = await nodes(visibleOnly: true);
      final leftover = await byLabel(ns0, 'Cancel');
      if (leftover != null &&
          (await byLabel(ns0, 'New automation') != null ||
              await byLabel(ns0, 'Edit automation') != null)) {
        await tapRef('${leftover['ref']}');
      }
      // Navigate to Settings if needed.
      var ns = await nodes();
      if (await byLabel(ns, 'Automations') == null) {
        // A first-run About overlay may cover the home rail: close it.
        final railAll = ns
            .where(
              (n) =>
                  n['type'] == 'button' &&
                  n['visibleInViewport'] == true &&
                  (((n['center']! as Map<String, Object?>)['y']! as num) < 60),
            )
            .toList()
          ..sort(
            (a, b) => ((a['center']! as Map<String, Object?>)['x']! as num)
                .compareTo(
              (b['center']! as Map<String, Object?>)['x']! as num,
            ),
          );
        if (railAll.length < 4 && railAll.isNotEmpty) {
          await tapRef('${railAll.first['ref']}');
          ns = await nodes();
        }
        final rail = ns
            .where(
              (n) =>
                  n['type'] == 'button' &&
                  n['visibleInViewport'] == true &&
                  (((n['center']! as Map<String, Object?>)['y']! as num) < 60),
            )
            .toList()
          ..sort(
            (a, b) => ((a['center']! as Map<String, Object?>)['x']! as num)
                .compareTo(
              (b['center']! as Map<String, Object?>)['x']! as num,
            ),
          );
        await tapRef('${rail[3]['ref']}');
      }
      await scrollTo('Automations');
      // The add button: the LEFT icon button on the header band.
      var ns2 = await nodes(visibleOnly: true);
      final header = (await byLabel(ns2, 'Automations'))!;
      final hy = (header['center']! as Map<String, Object?>)['y']! as num;
      final headerButtons = ns2
          .where(
            (n) =>
                n['type'] == 'button' &&
                (((n['center']! as Map<String, Object?>)['y']! as num) - hy)
                        .abs() <
                    25 &&
                (((n['center']! as Map<String, Object?>)['x']! as num) > 550),
          )
          .toList()
        ..sort(
          (a, b) => ((a['center']! as Map<String, Object?>)['x']! as num)
              .compareTo((b['center']! as Map<String, Object?>)['x']! as num),
        );
      if (headerButtons.length < 2) {
        stderr.writeln('add/refresh buttons not found');
        exit(2);
      }
      await tapRef('${headerButtons.first['ref']}');
      await Future<void>.delayed(const Duration(milliseconds: 900));

      // Fill the form.
      ns2 = await nodes();
      await typeInto(ns2, 'Name', target);
      final scheduled = await byLabel(ns2, 'Scheduled');
      if (scheduled == null) {
        stderr.writeln('Scheduled segment not found');
        exit(2);
      }
      await tapRef('${scheduled['ref']}');
      ns2 = await nodes();
      final repeating = await byLabel(ns2, 'Repeating');
      if (repeating == null) {
        stderr.writeln('Repeating segment not found');
        exit(2);
      }
      await tapRef('${repeating['ref']}');
      ns2 = await nodes();
      // Interval field: the unlabeled textfield below the segments row.
      final repeatingY =
          ((await byLabel(ns2, 'Repeating'))!['center']!
              as Map<String, Object?>)['y']! as num;
      final interval = ns2
          .where(
            (n) =>
                '${n['type']}'.toLowerCase().contains('textfield') &&
                ('${n['label']}' == 'null' || '${n['label']}'.isEmpty) &&
                (((n['center']! as Map<String, Object?>)['y']! as num) >
                    repeatingY),
          )
          .toList()
        ..sort(
          (a, b) => ((a['center']! as Map<String, Object?>)['y']! as num)
              .compareTo((b['center']! as Map<String, Object?>)['y']! as num),
        );
      if (interval.isEmpty) {
        stderr.writeln('interval field not found');
        exit(2);
      }
      await step('enter-interval', () {
        return ext(
          ToolkitExtensions.enterText,
          args: {'ref': interval.first['ref'], 'text': '2'},
        );
      });
      await typeInto(ns2, 'Command', '/usr/bin/true');
      await shot('form');
      final save = await byLabel(await nodes(visibleOnly: true), 'Save');
      if (save == null) {
        stderr.writeln('Save not found');
        exit(2);
      }
      await tapRef('${save['ref']}');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await scrollTo(target);
      await shot('row');
      final ns3 = await nodes();
      final row = await byLabel(ns3, target);
      stdout.writeln('row present: ${row != null}');
      for (final n in ns3) {
        final label = '${n['label']}';
        if (label.contains(target) || label.startsWith('interval:')) {
          stdout.writeln('row: $label');
        }
      }
      exit(0);
    }

    if (stage == 'edit') {
      await scrollTo(target);
      final ns = await nodes(visibleOnly: true);
      final row = ns
          .where((n) => '${n['label']}'.contains(target))
          .firstOrNull;
      if (row == null) {
        stderr.writeln('row $target not visible');
        exit(2);
      }
      await tapRef('${row['ref']}');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await shot('edit-sheet');
      // The interval field shows '1' (one day): set '3'.
      var ns2 = await nodes();
      final fields = ns2
          .where((n) => '${n['type']}'.toLowerCase().contains('textfield'))
          .toList()
        ..sort(
          (a, b) => ((a['center']! as Map<String, Object?>)['y']! as num)
              .compareTo((b['center']! as Map<String, Object?>)['y']! as num),
        );
      final interval = fields
          .where((n) => '${n['value'] ?? n['label']}'.contains('1'))
          .firstOrNull;
      if (interval == null) {
        stderr.writeln('interval field with value 1 not found');
        exit(2);
      }
      await step('enter-3', () {
        return ext(
          ToolkitExtensions.enterText,
          args: {'ref': interval['ref'], 'text': '3'},
        );
      });
      final save = await byLabel(await nodes(visibleOnly: true), 'Save');
      await tapRef('${save!['ref']}');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await scrollTo(target);
      await shot('edited');
      for (final n in await nodes()) {
        final label = '${n['label']}';
        if (label.startsWith('interval:')) stdout.writeln('row: $label');
      }
      exit(0);
    }

    if (stage == 'delete') {
      await scrollTo(target);
      final ns = await nodes(visibleOnly: true);
      final row = ns
          .where((n) => '${n['label']}'.contains(target))
          .firstOrNull;
      if (row == null) {
        stderr.writeln('row $target not visible');
        exit(2);
      }
      await tapRef('${row['ref']}');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      var ns2 = await nodes(visibleOnly: true);
      final delete = await byLabel(ns2, 'Delete');
      if (delete == null) {
        stderr.writeln('Delete button not found');
        exit(2);
      }
      await tapRef('${delete['ref']}');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      ns2 = await nodes(visibleOnly: true);
      final confirm = await byLabel(ns2, 'Confirm');
      if (confirm == null) {
        stderr.writeln('Confirm not found');
        exit(2);
      }
      await tapRef('${confirm['ref']}');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await scrollTo(target);
      await shot('deleted');
      final gone = (await nodes())
          .where((n) => '${n['label']}'.contains(target))
          .isEmpty;
      stdout.writeln('row gone: $gone');
      exit(gone ? 0 : 4);
    }
    stderr.writeln('unknown stage $stage');
    exit(1);
  } on Object catch (error) {
    stderr.writeln('probe failed: $error');
    exit(1);
  }
}
