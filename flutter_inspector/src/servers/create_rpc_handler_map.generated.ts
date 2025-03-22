// GENERATED CODE - DO NOT MODIFY BY HAND
// This file is generated from server_tools_handler.yaml
// Run "npm run generate-rpc-handlers" to update

import { FlutterRpcHandlers } from "./flutter_rpc_handlers.generated.js";

/**
 * Generated createRpcHandlerMap method for the FlutterInspectorServer class.
 * 
 * @param rpcHandlers The FlutterRpcHandlers instance
 * @param handlePortParam A function to extract the port parameter from a request
 * @returns A mapping of tool names to handler functions
 */
export function createRpcHandlerMap(
  rpcHandlers: FlutterRpcHandlers,
  handlePortParam: (request: any) => number
): Record<string, any> {
  return {
    "get_vm": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleGetVm(port);
    },
    "dart_io_socket_profiling_enabled": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDartIoSocketProfilingEnabled(port, params);
    },
    "dart_io_http_enable_timeline_logging": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDartIoHttpEnableTimelineLogging(port, params);
    },
    "dart_io_get_version": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDartIoGetVersion(port);
    },
    "dart_io_get_http_profile_request": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDartIoGetHttpProfileRequest(port, params);
    },
    "dart_io_get_socket_profile": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDartIoGetSocketProfile(port);
    },
    "dart_io_clear_socket_profile": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDartIoClearSocketProfile(port);
    },
    "dart_io_get_http_profile": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDartIoGetHttpProfile(port);
    },
    "dart_io_clear_http_profile": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDartIoClearHttpProfile(port);
    },
    "dart_io_get_open_files": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDartIoGetOpenFiles(port);
    },
    "dart_io_get_open_file_by_id": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDartIoGetOpenFileById(port, params);
    },
    "debug_dump_render_tree": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDebugDumpRenderTree(port);
    },
    "inspector_get_properties": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetProperties(port, params);
    },
    "debug_set_debug_paint": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDebugSetDebugPaint(port, params);
    },
    "inspector_get_root_widget_summary_tree": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetRootWidgetSummaryTree(port, params);
    },
    "debug_dump_layer_tree": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDebugDumpLayerTree(port);
    },
    "debug_dump_semantics_tree": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDebugDumpSemanticsTree(port);
    },
    "debug_dump_semantics_tree_inverse": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDebugDumpSemanticsTreeInverse(port);
    },
    "debug_dump_focus_tree": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleDebugDumpFocusTree(port);
    },
    "debug_paint_baselines_enabled": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDebugPaintBaselinesEnabled(port, params);
    },
    "debug_disable_clip_layers": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDebugDisableClipLayers(port, params);
    },
    "debug_disable_physical_shape_layers": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDebugDisablePhysicalShapeLayers(port, params);
    },
    "debug_disable_opacity_layers": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDebugDisableOpacityLayers(port, params);
    },
    "repaint_rainbow": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleRepaintRainbow(port, params);
    },
    "debug_allow_banner": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleDebugAllowBanner(port, params);
    },
    "flutter_core_invert_oversized_images": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreInvertOversizedImages(port, params);
    },
    "flutter_core_platform_override": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCorePlatformOverride(port, params);
    },
    "flutter_core_brightness_override": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreBrightnessOverride(port, params);
    },
    "flutter_core_time_dilation": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreTimeDilation(port, params);
    },
    "flutter_core_evict": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreEvict(port, params);
    },
    "inspector_screenshot": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorScreenshot(port);
    },
    "inspector_get_layout_explorer_node": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetLayoutExplorerNode(port, params);
    },
    "inspector_track_rebuild_dirty_widgets": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorTrackRebuildDirtyWidgets(port, params);
    },
    "inspector_set_selection_by_id": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorSetSelectionById(port, params);
    },
    "inspector_get_parent_chain": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetParentChain(port, params);
    },
    "inspector_get_children_summary_tree": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetChildrenSummaryTree(port, params);
    },
    "inspector_get_details_subtree": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetDetailsSubtree(port, params);
    },
    "inspector_get_selected_widget": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorGetSelectedWidget(port);
    },
    "inspector_get_selected_summary_widget": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorGetSelectedSummaryWidget(port);
    },
    "inspector_is_widget_creation_tracked": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorIsWidgetCreationTracked(port);
    },
    "inspector_structured_errors": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorStructuredErrors(port, params);
    },
    "inspector_show": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorShow(port, params);
    },
    "flutter_core_profile_platform_channels": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreProfilePlatformChannels(port, params);
    },
    "flutter_core_profile_render_object_paints": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreProfileRenderObjectPaints(port, params);
    },
    "flutter_core_profile_render_object_layouts": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreProfileRenderObjectLayouts(port, params);
    },
    "flutter_core_show_performance_overlay": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreShowPerformanceOverlay(port, params);
    },
    "flutter_core_profile_widget_builds": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreProfileWidgetBuilds(port, params);
    },
    "flutter_core_profile_user_widget_builds": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleFlutterCoreProfileUserWidgetBuilds(port, params);
    },
    "inspector_track_repaint_widgets": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorTrackRepaintWidgets(port, params);
    },
    "inspector_widget_location_id_map": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorWidgetLocationIdMap(port);
    },
    "inspector_dispose_all_groups": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorDisposeAllGroups(port);
    },
    "inspector_dispose_group": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorDisposeGroup(port, params);
    },
    "inspector_is_widget_tree_ready": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorIsWidgetTreeReady(port);
    },
    "inspector_dispose_id": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorDisposeId(port, params);
    },
    "inspector_set_pub_root_directories": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorSetPubRootDirectories(port, params);
    },
    "inspector_add_pub_root_directories": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorAddPubRootDirectories(port, params);
    },
    "inspector_remove_pub_root_directories": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorRemovePubRootDirectories(port, params);
    },
    "inspector_get_pub_root_directories": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorGetPubRootDirectories(port);
    },
    "inspector_get_children": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetChildren(port, params);
    },
    "inspector_get_children_details_subtree": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetChildrenDetailsSubtree(port, params);
    },
    "inspector_get_root_widget": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorGetRootWidget(port);
    },
    "inspector_get_root_widget_summary_tree_with_previews": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorGetRootWidgetSummaryTreeWithPreviews(port, params);
    },
    "inspector_get_root_widget_tree": (request: any) => {
      const port = handlePortParam(request);
      
      return rpcHandlers.handleInspectorGetRootWidgetTree(port);
    },
    "inspector_set_flex_fit": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorSetFlexFit(port, params);
    },
    "inspector_set_flex_factor": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorSetFlexFactor(port, params);
    },
    "inspector_set_flex_properties": (request: any) => {
      const port = handlePortParam(request);
      const params = request.params.arguments;
      return rpcHandlers.handleInspectorSetFlexProperties(port, params);
    },
  };
}
