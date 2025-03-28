import {
  FlutterRpcHandlers,
  rpcToolConfigs,
  RpcToolName,
} from "./flutter_rpc_handlers.generated.js";

/**
 * Generated createRpcHandlerMap method for the FlutterInspectorServer class.
 */
export function createRpcHandlerMap(
  rpcHandlers: FlutterRpcHandlers
): Record<RpcToolName, (request: any) => Promise<unknown>> {
  return Object.fromEntries(
    Object.keys(rpcToolConfigs).map((toolName) => [
      toolName,
      (request: any) =>
        rpcHandlers.handleToolRequest(toolName as RpcToolName, request),
    ])
  ) as Record<RpcToolName, (request: any) => Promise<unknown>>;
}
