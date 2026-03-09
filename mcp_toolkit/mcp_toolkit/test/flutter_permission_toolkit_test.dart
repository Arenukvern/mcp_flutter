import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  test(
    'permission entries are registered only when a delegate is provided',
    () {
      final baseEntries = getFlutterMcpToolkitEntries(
        binding: MCPToolkitBinding.instance,
      );
      final baseNames = baseEntries.map((final entry) => entry.key).toSet();

      expect(baseNames.contains(flutterPermissionStatusTool), isFalse);
      expect(baseNames.contains(flutterPermissionRequestTool), isFalse);
      expect(baseNames.contains(flutterPermissionOpenSettingsTool), isFalse);
      expect(
        baseNames.contains(flutterPermissionSupportedKindsResource),
        isFalse,
      );

      final permissionEntries = getFlutterMcpPermissionEntries(
        delegate: _FakePermissionDelegate(),
      );
      final permissionNames = permissionEntries.map((final entry) => entry.key);

      expect(permissionNames, contains(flutterPermissionStatusTool));
      expect(permissionNames, contains(flutterPermissionRequestTool));
      expect(permissionNames, contains(flutterPermissionOpenSettingsTool));
      expect(
        permissionNames,
        contains(flutterPermissionSupportedKindsResource),
      );
    },
  );
}

final class _FakePermissionDelegate implements MCPPermissionDelegate {
  @override
  Iterable<String> listSupportedPermissionKinds() => const <String>[
    'visual_capture',
  ];

  @override
  Future<MCPPermissionResult> getPermissionStatus({
    required final String kind,
  }) async => MCPPermissionResult(kind: kind, status: 'granted');

  @override
  Future<MCPPermissionResult> openPermissionSettings({
    required final String kind,
  }) async => MCPPermissionResult(kind: kind, status: 'denied');

  @override
  Future<MCPPermissionResult> requestPermission({
    required final String kind,
  }) async => MCPPermissionResult(kind: kind, status: 'granted');
}
