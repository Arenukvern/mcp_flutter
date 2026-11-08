import 'dart:io';

import 'native_layer_evidence.dart';

/// Single SHA source for provisional test pins: [tool/ci/oka_consumer_pin.txt].
String? readOkaConsumerPinSha({Directory? repoRoot}) {
  final root = repoRoot ?? harnessRepoRoot();
  final pinFile = File('${root.path}/tool/ci/oka_consumer_pin.txt');
  if (!pinFile.existsSync()) return null;
  final pin = pinFile.readAsStringSync().trim();
  return pin.isEmpty ? null : pin;
}
