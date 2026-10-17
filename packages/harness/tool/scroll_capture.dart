import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Scrolls N times, capturing a screenshot after each — the visual
/// ground truth semantics can't give (offscreen nodes still appear in
/// the semantic tree).
Future<void> main(List<String> args) async {
  final rounds = args.isNotEmpty ? int.parse(args.first) : 4;
  final client = await VmClient.connect(
    Uri.parse('http://127.0.0.1:58092/zhhsqmOHgUQ=/'),
  );
  for (var i = 0; i < rounds; i++) {
    await client.callExtension(ToolkitExtensions.scroll, args: {
      'direction': 'down',
      'distance': 900,
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final png = await ToolkitDriver(client).screenshot();
    final file = File('/tmp/la-scroll-$i.png');
    await file.writeAsBytes(png);
    stdout.writeln('${file.path} (${png.length} bytes)');
  }
}
