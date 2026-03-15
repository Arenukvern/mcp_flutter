import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter/semantics.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

Future<void> bootstrapTestApp({
  required final Future<void> Function() registerInitialEntries,
  required final void Function() runApp,
  final Future<void> Function()? registerDelayedEntries,
}) async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kIsWeb) {
        SemanticsBinding.instance.ensureSemantics();
      }
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit()
        ..initializeFlutterLiveEditToolkit();

      await registerInitialEntries();
      runApp();

      if (registerDelayedEntries != null) {
        Timer(const Duration(seconds: 5), () async {
          await registerDelayedEntries();
        });
      }
    },
    (final error, final stack) {
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}
