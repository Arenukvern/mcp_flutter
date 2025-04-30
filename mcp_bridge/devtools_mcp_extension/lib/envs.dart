// ignore_for_file: do_not_use_environment

class Envs {
  static const tsRpc = (
    host: String.fromEnvironment('TS_RPC_HOST', defaultValue: 'localhost'),
    port: int.fromEnvironment('TS_RPC_PORT', defaultValue: 3535),
    path: String.fromEnvironment('TS_RPC_PATH', defaultValue: 'ext-ws'),
  );
  static const flutterRpc = (
    host: String.fromEnvironment('FLUTTER_RPC_HOST', defaultValue: 'localhost'),
    port: int.fromEnvironment('FLUTTER_RPC_PORT', defaultValue: 8181),
    path: String.fromEnvironment('FLUTTER_RPC_PATH', defaultValue: 'ws'),
  );
  static const forwardingServer = (
    host: String.fromEnvironment(
      'FORWARDING_SERVER_HOST',
      defaultValue: 'localhost',
    ),
    port: int.fromEnvironment('FORWARDING_SERVER_PORT', defaultValue: 8143),
    path: String.fromEnvironment(
      'FORWARDING_SERVER_PATH',
      defaultValue: 'forward',
    ),
  );
}
