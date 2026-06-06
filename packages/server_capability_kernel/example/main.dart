import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';

/// Example entry — kernel is a contracts package; hosts implement [Capability].
void describeCapability(Capability capability) {
  // ignore: avoid_print
  print('Capability id: ${capability.id} (${capability.version})');
}

void main() {
  // ignore: avoid_print
  print(
    'Import flutter_mcp_toolkit_capability_kernel and implement Capability.',
  );
}
