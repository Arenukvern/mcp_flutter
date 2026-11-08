/// Session teardown outcome from a bounded owner (not bare exit codes).
class BoundedSessionSettlement {
  const BoundedSessionSettlement({
    required this.exitCode,
    required this.physicallySettled,
    required this.survivors,
    required this.cause,
    required this.appStopAcknowledged,
    required this.appStopRequestId,
  });

  final int exitCode;
  final bool physicallySettled;
  final List<String> survivors;
  final String cause;
  final bool appStopAcknowledged;
  final int? appStopRequestId;

  Map<String, Object?> toJson() => {
        'exitCode': exitCode,
        'physicallySettled': physicallySettled,
        'survivors': survivors,
        'cause': cause,
        'appStopAcknowledged': appStopAcknowledged,
        'appStopRequestId': appStopRequestId,
      };
}
