import 'package:flutter/foundation.dart';

import '../mcp_toolkit_binding_base.dart';
import 'web_bridge_client.dart';

mixin WebServiceExtensions on MCPToolkitBindingBase {
  Future<void> initializeWebBridge({required String bridgeUrl}) async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Web bridge can only be initialized on web platform',
      );
    }
    throw UnsupportedError('WebServiceExtensions requires web implementation');
  }

  @override
  void registerServiceExtension({
    required String name,
    required ServiceExtensionCallback callback,
  }) {
    super.registerServiceExtension(name: name, callback: callback);
  }

  void disposeWebBridge() {}
}

