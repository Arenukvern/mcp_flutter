import 'package:flutter/foundation.dart';

/// In-memory shipments for the canonical showcase journey.
@immutable
class Shipment {
  const Shipment({
    required this.trackingId,
    required this.recipientName,
    required this.recipientEmail,
    required this.weightKg,
    required this.createdAt,
  });

  final String trackingId;
  final String recipientName;
  final String recipientEmail;
  final double weightKg;
  final DateTime createdAt;

  String get listLabel =>
      '$trackingId · $recipientName · ${weightKg.toStringAsFixed(1)} kg';
}

/// Shared store for the polished home/list flow (also readable via MCP tools).
class ShipmentStore extends ChangeNotifier {
  ShipmentStore._();

  static final ShipmentStore instance = ShipmentStore._();

  final List<Shipment> _shipments = <Shipment>[];
  var _nextSequence = 1001;

  List<Shipment> get shipments => List<Shipment>.unmodifiable(_shipments);

  bool get isEmpty => _shipments.isEmpty;

  Future<void> createShipment({
    required String recipientName,
    required String recipientEmail,
    required double weightKg,
    Duration simulatedLatency = const Duration(milliseconds: 900),
  }) async {
    await Future<void>.delayed(simulatedLatency);
  }

  Shipment addShipment({
    required String recipientName,
    required String recipientEmail,
    required double weightKg,
  }) {
    final id = 'SHP-${_nextSequence++}';
    final shipment = Shipment(
      trackingId: id,
      recipientName: recipientName.trim(),
      recipientEmail: recipientEmail.trim(),
      weightKg: weightKg,
      createdAt: DateTime.now().toUtc(),
    );
    _shipments.insert(0, shipment);
    notifyListeners();
    return shipment;
  }

  @visibleForTesting
  void resetForTest() {
    _shipments.clear();
    _nextSequence = 1001;
    notifyListeners();
  }

  Map<String, Object?> snapshot() => <String, Object?>{
    'count': _shipments.length,
    'latestTrackingId': _shipments.isEmpty ? null : _shipments.first.trackingId,
  };
}
