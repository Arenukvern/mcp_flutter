import '../mcp_models.dart';

/// Parses an optional coordinate / view id from a VM service extension request.
///
/// Unlike [jsonDecodeInt], missing keys stay null and `"0"` parses as [0].
int? optionalCoordinateIntFromRequest(
  ServiceExtensionRequestMap parameters,
  String key,
) {
  if (!parameters.containsKey(key)) {
    return null;
  }
  final raw = parameters[key];
  if (raw == null || raw.isEmpty || raw != raw.trim()) {
    return null;
  }
  if (!RegExp(r'^[0-9]+$').hasMatch(raw)) {
    return null;
  }
  return int.tryParse(raw);
}
