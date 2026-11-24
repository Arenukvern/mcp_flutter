import 'package:flutter/material.dart';
import 'package:test_app/canonical_showcase/new_shipment_screen.dart';
import 'package:test_app/shipment_store.dart';

/// Primary product-facing journey: browse shipments and create new ones.
class ShipmentsHomeScreen extends StatelessWidget {
  const ShipmentsHomeScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      identifier: 'shipment_list_screen',
      label: 'Shipments',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Outbound'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/qa'),
              child: const Text('QA lab'),
            ),
          ],
        ),
        floatingActionButton: Semantics(
          button: true,
          identifier: 'shipment_create_button',
          label: 'Create shipment',
          child: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.of(context).pushNamed(NewShipmentScreen.routeName);
            },
            icon: const Icon(Icons.add),
            label: const Text('New shipment'),
          ),
        ),
        body: AnimatedBuilder(
          animation: ShipmentStore.instance,
          builder: (final context, final _) {
            final store = ShipmentStore.instance;
            if (store.isEmpty) {
              return Center(
                child: Semantics(
                  container: true,
                  identifier: 'shipment_empty_state',
                  label: 'No shipments yet',
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No shipments yet',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create one to see async loading, validation, and list updates.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: store.shipments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (final context, final index) {
                final item = store.shipments[index];
                return Semantics(
                  container: true,
                  identifier: 'shipment_list_item_${item.trackingId}',
                  label: item.listLabel,
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(item.trackingId),
                      subtitle: Text(
                        '${item.recipientName} · ${item.recipientEmail}',
                      ),
                      trailing: Text('${item.weightKg.toStringAsFixed(1)} kg'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}