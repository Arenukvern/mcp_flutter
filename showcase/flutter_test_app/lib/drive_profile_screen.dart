import 'package:flutter/material.dart';

/// Named-route target for [`showcase/drivers/bin/drive_flutter.dart`].
class DriveProfileScreen extends StatelessWidget {
  const DriveProfileScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final name =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'friend';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: <Widget>[
            Text(
              'Hello, $name!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
