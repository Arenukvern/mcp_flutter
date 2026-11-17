import 'package:flutter_mcp_toolkit_server/src/cli/diagnostics/doctor_human_output.dart';

/// Prints whether NO_COLOR is treated as active for doctor human output.
void main() {
  if (noColorEnvDisablesAnsi()) {
    // ignore: avoid_print
    print('no_color_active');
    return;
  }
  // ignore: avoid_print
  print('no_color_inactive');
}
