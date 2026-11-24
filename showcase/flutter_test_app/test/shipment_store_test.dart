import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/shipment_store.dart';

void main() {
  test('addShipment prepends and exposes tracking id', () {
    final store = ShipmentStore.instance..resetForTest();
    expect(store.isEmpty, isTrue);
    final s = store.addShipment(
      recipientName: 'Ada',
      recipientEmail: 'ada@example.com',
      weightKg: 2.5,
    );
    expect(store.shipments.length, 1);
    expect(store.shipments.first.trackingId, s.trackingId);
    expect(s.trackingId, startsWith('SHP-'));
  });
}
