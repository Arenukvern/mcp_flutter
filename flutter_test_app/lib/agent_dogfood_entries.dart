import 'package:mcp_toolkit/mcp_toolkit.dart';

/// Optional paths to sibling repos (visual harness). Override via --dart-define.
const _visualReconstructRoot = String.fromEnvironment(
  'INTENTCALL_VISUAL_RECONSTRUCT_ROOT',
  defaultValue: '../../flutter_visual_reconstruct',
);
const _harnessRoot = String.fromEnvironment(
  'INTENTCALL_HARNESS_ROOT',
  defaultValue: '../../flutter_harness',
);

/// Hand-written [AgentCallEntry] for web dogfood (iteration 5+).
Set<AgentCallEntry> buildAgentDogfoodEntries() => {
  AgentCallEntry.tool(
    namespace: 'app',
    name: 'dogfood_reconstruct_start',
    description:
        'Phase C cold path: IR schema, harness deconstruct smoke, route hint',
    inputSchema: const {
      'type': 'object',
      'additionalProperties': false,
      'properties': {},
    },
    handler: (_) async => AgentResult.success(
      message: 'reconstruct.start dogfood metadata',
      data: const {
        'ok': true,
        'job': 'reconstruct.start',
        'kind': 'app_dogfood_reconstruct_start',
        'route': '/visual-reconstruct',
        'golden': 'test/goldens/visual_reconstruct.png',
        'ir_schema': '$_harnessRoot/specs/ir_v0.schema.yaml',
        'harness_smoke':
            '$_harnessRoot/harness/examples/visual_reconstruct/deconstruct_smoke.hs.yaml',
        'checkpoint_protocol': {
          'autonomous': 'guild pass from visual_reconstruct compare',
          'require_approval': 'HS checkpoint step + .approved marker',
        },
        'dogfood_boot': 'DOGFOOD_VISUAL=1 make web-showcase',
      },
    ),
  ),
  AgentCallEntry.tool(
    namespace: 'app',
    name: 'dogfood_visual_reconstruct_info',
    description:
        'Metadata for visual reconstruction dogfood (golden path, route, guild)',
    inputSchema: const {
      'type': 'object',
      'additionalProperties': false,
      'properties': {},
    },
    handler: (_) async => AgentResult.success(
      message: 'visual reconstruct fixture',
      data: const {
        'ok': true,
        'kind': 'app_dogfood_visual_reconstruct',
        'route': '/visual-reconstruct',
        'golden': 'test/goldens/visual_reconstruct.png',
        'guild_profile_warm':
            '$_visualReconstructRoot/profiles/dogfood_warm.yaml',
        'guild_profile_strict':
            '$_visualReconstructRoot/profiles/default_guild.yaml',
        'harness_smoke':
            '$_harnessRoot/harness/examples/visual_reconstruct/compare_smoke.hs.yaml',
        'harness_warm_path_direct':
            '$_harnessRoot/harness/examples/visual_reconstruct/warm_path_direct.hs.yaml',
        'harness_warm_path_legacy':
            '$_harnessRoot/harness/examples/visual_reconstruct/warm_path.hs.yaml',
        'dogfood_boot': 'DOGFOOD_VISUAL=1 make web-showcase',
      },
    ),
  ),
  AgentCallEntry.tool(
    namespace: 'app',
    name: 'dogfood_ping',
    description:
        'Dogfood ping — returns a fixed payload for registry/invoke checks',
    inputSchema: const {
      'type': 'object',
      'additionalProperties': false,
      'properties': {},
    },
    handler: (_) async => AgentResult.success(
      message: 'dogfood pong',
      data: const {'ok': true, 'kind': 'app_dogfood_ping', 'iteration': 5},
    ),
  ),
};
