import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

int cliPositivePort(
  String? value, {
  required int fallback,
  required String flag,
}) {
  if (value == null || value.isEmpty) {
    return fallback;
  }
  final parsed = parseStrictPositiveDecimalPort(value);
  if (parsed == null) {
    throw FormatException(
      'Invalid --$flag: expected decimal port 1-$kMaxTcpPort',
    );
  }
  return parsed;
}

int? cliOptionalPort(String? value, {required String flag}) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final parsed = parseStrictPositiveDecimalPort(value);
  if (parsed == null) {
    throw FormatException(
      'Invalid --$flag: expected decimal port 1-$kMaxTcpPort',
    );
  }
  return parsed;
}