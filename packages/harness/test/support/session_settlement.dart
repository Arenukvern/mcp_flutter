/// Session teardown outcome from a bounded owner (not bare exit codes).
class BoundedSessionSettlement {
  const BoundedSessionSettlement({
    required this.exitCode,
    required this.physicallySettled,
    required this.survivors,
    required this.cause,
    required this.appStopAcknowledged,
    required this.appStopRequestId,
    required this.cooperativeAckGap,
  });

  final int exitCode;
  final bool physicallySettled;
  final List<String> survivors;
  final String cause;
  final bool appStopAcknowledged;
  final int? appStopRequestId;

  /// `app.stop` RPC/event ack absent but [physicallySettled] with owner stop.
  /// Harness may still pass capture proof while recording this gap honestly.
  final bool cooperativeAckGap;

  bool get shutdownTruthful =>
      appStopAcknowledged ||
      (cooperativeAckGap &&
          physicallySettled &&
          survivors.isEmpty &&
          appStopRequestId != null);

  Map<String, Object?> toJson() => {
        'exitCode': exitCode,
        'physicallySettled': physicallySettled,
        'survivors': survivors,
        'cause': cause,
        'appStopAcknowledged': appStopAcknowledged,
        'appStopRequestId': appStopRequestId,
        'cooperativeAckGap': cooperativeAckGap,
        'shutdownTruthful': shutdownTruthful,
      };
}
