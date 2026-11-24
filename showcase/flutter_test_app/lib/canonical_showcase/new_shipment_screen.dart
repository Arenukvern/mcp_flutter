import 'package:flutter/material.dart';
import 'package:test_app/shipment_store.dart';

class NewShipmentScreen extends StatefulWidget {
  const NewShipmentScreen({super.key});

  static const routeName = '/shipments/new';

  @override
  State<NewShipmentScreen> createState() => _NewShipmentScreenState();
}

class _NewShipmentScreenState extends State<NewShipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _weightController = TextEditingController(text: '2.5');
  var _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final weight = double.parse(_weightController.text.trim());
    try {
      await ShipmentStore.instance.createShipment(
        recipientName: _nameController.text,
        recipientEmail: _emailController.text,
        weightKg: weight,
      );
      if (!mounted) return;
      ShipmentStore.instance.addShipment(
        recipientName: _nameController.text,
        recipientEmail: _emailController.text,
        weightKg: weight,
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Semantics(
      container: true,
      identifier: 'shipment_new_screen',
      label: 'New shipment',
      child: Scaffold(
        appBar: AppBar(title: const Text('New shipment')),
        body: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Semantics(
                    textField: true,
                    identifier: 'shipment_recipient_name_field',
                    label: 'Recipient name',
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Recipient name',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (final v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 2) return 'Enter at least 2 characters';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    textField: true,
                    identifier: 'shipment_recipient_email_field',
                    label: 'Recipient email',
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Recipient email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (final v) {
                        final t = v?.trim() ?? '';
                        if (!t.contains('@') || !t.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    textField: true,
                    identifier: 'shipment_weight_kg_field',
                    label: 'Weight in kilograms',
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (final v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed <= 0 || parsed > 500) {
                          return 'Enter weight between 0.1 and 500 kg';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          identifier: 'shipment_form_cancel_button',
                          label: 'Cancel',
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          button: true,
                          identifier: 'shipment_form_submit_button',
                          label: 'Create shipment',
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: const Text('Create shipment'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_submitting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      identifier: 'shipment_loading_overlay',
                      label: 'Creating shipment',
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Booking label…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}