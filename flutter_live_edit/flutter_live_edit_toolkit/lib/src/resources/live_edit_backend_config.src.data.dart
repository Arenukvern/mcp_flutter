import '../models/models.dart';

/// Immutable data for [LiveEditBackendConfigResource].
final class LiveEditBackendConfigResourceData {
  const LiveEditBackendConfigResourceData({
    this.globalBackendId,
    this.availableBackends = const <LiveEditAgentBackend>[],
    this.inferenceConfigByBackendId = const <String, LiveEditInferenceConfig>{},
  });

  final String? globalBackendId;
  final List<LiveEditAgentBackend> availableBackends;
  final Map<String, LiveEditInferenceConfig> inferenceConfigByBackendId;

  static const LiveEditBackendConfigResourceData initial =
      LiveEditBackendConfigResourceData();

  LiveEditBackendConfigResourceData copyWith({
    final String? globalBackendId,
    final List<LiveEditAgentBackend>? availableBackends,
    final Map<String, LiveEditInferenceConfig>? inferenceConfigByBackendId,
  }) => LiveEditBackendConfigResourceData(
    globalBackendId: globalBackendId ?? this.globalBackendId,
    availableBackends: availableBackends ?? this.availableBackends,
    inferenceConfigByBackendId:
        inferenceConfigByBackendId ?? this.inferenceConfigByBackendId,
  );
}
