import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

/// Thrown when a CLI port flag is not a strict decimal port in range.
final class CliPortUsageException implements Exception {
  CliPortUsageException(this.flag, this.value);

  final String flag;
  final String value;

  String get message =>
      'Invalid --$flag="$value": expected decimal port 1-$kMaxTcpPort';
}

int cliPositivePort(
  String? value, {
  required int fallback,
  required String flag,
}) {
  if (value == null || value.isEmpty) {
    return fallback;
  }
  if (RegExp(r'^0[0-9]+$').hasMatch(value)) {
    throw CliPortUsageException(flag, value);
  }
  final parsed = parseStrictPositiveDecimalPort(value);
  if (parsed == null) {
    throw CliPortUsageException(flag, value);
  }
  return parsed;
}

int? cliOptionalPort(String? value, {required String flag}) {
  if (value == null || value.isEmpty) {
    return null;
  }
  if (RegExp(r'^0[0-9]+$').hasMatch(value)) {
    throw CliPortUsageException(flag, value);
  }
  final parsed = parseStrictPositiveDecimalPort(value);
  if (parsed == null) {
    throw CliPortUsageException(flag, value);
  }
  return parsed;
}
