
export const rpcToolConfigs = {
  dart_io_socket_profiling_enabled: {
    rpcMethod: 'ext.dart.io.socketProfilingEnabled',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_http_enable_timeline_logging: {
    rpcMethod: 'ext.dart.io.httpEnableTimelineLogging',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_get_version: {
    rpcMethod: 'ext.dart.io.getVersion',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_get_http_profile_request: {
    rpcMethod: 'ext.dart.io.getHttpProfileRequest',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_get_socket_profile: {
    rpcMethod: 'ext.dart.io.getSocketProfile',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_clear_socket_profile: {
    rpcMethod: 'ext.dart.io.clearSocketProfile',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_get_http_profile: {
    rpcMethod: 'ext.dart.io.getHttpProfile',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_clear_http_profile: {
    rpcMethod: 'ext.dart.io.clearHttpProfile',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_get_open_files: {
    rpcMethod: 'ext.dart.io.getOpenFiles',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  dart_io_get_open_file_by_id: {
    rpcMethod: 'ext.dart.io.getOpenFileById',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_dump_render_tree: {
    rpcMethod: 'ext.flutter.debugDumpRenderTree',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  inspector_get_properties: {
    rpcMethod: 'ext.flutter.inspector.getProperties',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  debug_set_debug_paint: {
    rpcMethod: 'ext.flutter.debugPaint',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  inspector_get_root_widget_summary_tree: {
    rpcMethod: 'ext.flutter.inspector.getRootWidgetSummaryTree',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  debug_dump_layer_tree: {
    rpcMethod: 'ext.flutter.debugDumpLayerTree',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_dump_semantics_tree: {
    rpcMethod: 'ext.flutter.debugDumpSemanticsTreeInTraversalOrder',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_dump_semantics_tree_inverse: {
    rpcMethod: 'ext.flutter.debugDumpSemanticsTreeInInverseHitTestOrder',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_dump_focus_tree: {
    rpcMethod: 'ext.flutter.debugDumpFocusTree',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_paint_baselines_enabled: {
    rpcMethod: 'ext.flutter.debugPaintBaselinesEnabled',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_disable_clip_layers: {
    rpcMethod: 'ext.flutter.debugDisableClipLayers',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_disable_physical_shape_layers: {
    rpcMethod: 'ext.flutter.debugDisablePhysicalShapeLayers',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_disable_opacity_layers: {
    rpcMethod: 'ext.flutter.debugDisableOpacityLayers',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  repaint_rainbow: {
    rpcMethod: 'ext.flutter.repaintRainbow',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  debug_allow_banner: {
    rpcMethod: 'ext.flutter.debugAllowBanner',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_invert_oversized_images: {
    rpcMethod: 'ext.flutter.invertOversizedImages',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_platform_override: {
    rpcMethod: 'ext.flutter.platformOverride',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_brightness_override: {
    rpcMethod: 'ext.flutter.brightnessOverride',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_time_dilation: {
    rpcMethod: 'ext.flutter.timeDilation',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_evict: {
    rpcMethod: 'ext.flutter.evict',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  inspector_screenshot: {
    rpcMethod: 'ext.flutter.inspector.screenshot',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_layout_explorer_node: {
    rpcMethod: 'ext.flutter.inspector.getLayoutExplorerNode',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_track_rebuild_dirty_widgets: {
    rpcMethod: 'ext.flutter.inspector.trackRebuildDirtyWidgets',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_set_selection_by_id: {
    rpcMethod: 'ext.flutter.inspector.setSelectionById',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_parent_chain: {
    rpcMethod: 'ext.flutter.inspector.getParentChain',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_children_summary_tree: {
    rpcMethod: 'ext.flutter.inspector.getChildrenSummaryTree',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_details_subtree: {
    rpcMethod: 'ext.flutter.inspector.getDetailsSubtree',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_selected_widget: {
    rpcMethod: 'ext.flutter.inspector.getSelectedWidget',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_selected_summary_widget: {
    rpcMethod: 'ext.flutter.inspector.getSelectedSummaryWidget',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_is_widget_creation_tracked: {
    rpcMethod: 'ext.flutter.inspector.isWidgetCreationTracked',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_structured_errors: {
    rpcMethod: 'ext.flutter.inspector.structuredErrors',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_show: {
    rpcMethod: 'ext.flutter.inspector.show',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  flutter_core_profile_platform_channels: {
    rpcMethod: 'ext.flutter.profilePlatformChannels',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_profile_render_object_paints: {
    rpcMethod: 'ext.flutter.profileRenderObjectPaints',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_profile_render_object_layouts: {
    rpcMethod: 'ext.flutter.profileRenderObjectLayouts',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_show_performance_overlay: {
    rpcMethod: 'ext.flutter.showPerformanceOverlay',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_profile_widget_builds: {
    rpcMethod: 'ext.flutter.profileWidgetBuilds',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  flutter_core_profile_user_widget_builds: {
    rpcMethod: 'ext.flutter.profileUserWidgetBuilds',
    needsDebugVerification: true,
    needsDartProxy: false
  },
  inspector_track_repaint_widgets: {
    rpcMethod: 'ext.flutter.inspector.trackRepaintWidgets',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_widget_location_id_map: {
    rpcMethod: 'ext.flutter.inspector.widgetLocationIdMap',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_dispose_all_groups: {
    rpcMethod: 'ext.flutter.inspector.disposeAllGroups',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_dispose_group: {
    rpcMethod: 'ext.flutter.inspector.disposeGroup',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_is_widget_tree_ready: {
    rpcMethod: 'ext.flutter.inspector.isWidgetTreeReady',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_dispose_id: {
    rpcMethod: 'ext.flutter.inspector.disposeId',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_set_pub_root_directories: {
    rpcMethod: 'ext.flutter.inspector.setPubRootDirectories',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_add_pub_root_directories: {
    rpcMethod: 'ext.flutter.inspector.addPubRootDirectories',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_remove_pub_root_directories: {
    rpcMethod: 'ext.flutter.inspector.removePubRootDirectories',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_pub_root_directories: {
    rpcMethod: 'ext.flutter.inspector.getPubRootDirectories',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_children: {
    rpcMethod: 'ext.flutter.inspector.getChildren',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_children_details_subtree: {
    rpcMethod: 'ext.flutter.inspector.getChildrenDetailsSubtree',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_root_widget: {
    rpcMethod: 'ext.flutter.inspector.getRootWidget',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_root_widget_summary_tree_with_previews: {
    rpcMethod: 'ext.flutter.inspector.getRootWidgetSummaryTreeWithPreviews',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_get_root_widget_tree: {
    rpcMethod: 'ext.flutter.inspector.getRootWidgetTree',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_set_flex_fit: {
    rpcMethod: 'ext.flutter.inspector.setFlexFit',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_set_flex_factor: {
    rpcMethod: 'ext.flutter.inspector.setFlexFactor',
    needsDebugVerification: true,
    needsDartProxy: true
  },
  inspector_set_flex_properties: {
    rpcMethod: 'ext.flutter.inspector.setFlexProperties',
    needsDebugVerification: true,
    needsDartProxy: true
  }
} as const;

export type RpcToolName = keyof typeof rpcToolConfigs;

import { RpcToolResponseType, RpcUtilities } from "../servers/rpc_utilities.js";

/**
 * Generated class containing handlers for Flutter RPC tools.
 *
 * This class is generated from server_tools_handler.yaml.
 * Do not edit this file directly.
 */
export class FlutterRpcHandlers {
  constructor(
    private rpcUtils: RpcUtilities,
    private handlePortParam: (request: any) => number
  ) {}

  async handleToolRequest(toolName: RpcToolName, request: any): Promise<RpcToolResponseType> {
    const config = rpcToolConfigs[toolName];
    if (!config) throw new Error(`Invalid tool request: ${toolName}`);
    
    const port = this.handlePortParam(request);
    const params = request?.params?.arguments;

    if (config.needsDebugVerification) {
      await this.rpcUtils.verifyFlutterDebugMode(port);
    }

    const result = await this.rpcUtils.callDartVm({
          method: config.rpcMethod,
          dartVmPort: port,
          params,
        });

    return this.rpcUtils.wrapResponse(Promise.resolve(result));
  }
}
