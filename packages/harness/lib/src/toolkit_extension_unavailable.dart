import 'toolkit_extensions.dart';

/// Optional toolkit verb missing on the bound isolate after
/// [kOptionalToolkitExtensionGrace] (see `vm_client.dart`).
final class ToolkitExtensionUnavailable implements Exception {
  const ToolkitExtensionUnavailable(
    this.extensionName, {
    this.minimumMcpToolkitVersion =
        ToolkitExtensions.minimumMcpToolkitVersionForFullDriverSet,
  });

  final String extensionName;
  final String minimumMcpToolkitVersion;

  @override
  String toString() =>
      'Service extension "$extensionName" is not registered on this app. '
      'Upgrade mcp_toolkit to >= $minimumMcpToolkitVersion for the full '
      'ToolkitDriver verb set, or register "$extensionName" in a custom '
      'toolkit entry set.';
}
