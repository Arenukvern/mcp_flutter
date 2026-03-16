import 'package:flutter/foundation.dart';

import 'live_edit_backend_config.src.data.dart';

/// Holds backend UI state: global backend id, available backends, inference config per backend.
final class LiveEditBackendConfigResource
    extends ValueNotifier<LiveEditBackendConfigResourceData> {
  LiveEditBackendConfigResource([
    super.initialValue = LiveEditBackendConfigResourceData.initial,
  ]);
}
