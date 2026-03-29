import 'package:flutter/foundation.dart';

export 'live_edit_flow_graph.src.data.dart';

import 'live_edit_flow_graph.src.data.dart';

final class LiveEditFlowGraphResource
    extends ValueNotifier<LiveEditFlowGraphResourceData> {
  LiveEditFlowGraphResource([final LiveEditFlowGraphResourceData? initialValue])
    : super(initialValue ?? LiveEditFlowGraphResourceData.initial);
}
