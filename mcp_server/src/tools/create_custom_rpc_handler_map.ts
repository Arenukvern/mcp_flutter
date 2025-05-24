import {
  CallToolRequest,
  CallToolResult,
} from "@modelcontextprotocol/sdk/types.js";
import { Logger } from "../logger.js";
import { execAsync, RpcUtilities } from "../servers/rpc_utilities.js";
import { FlutterPort, IsolateInfo } from "../types/types.js";

// Define a type for the handler function
export type RpcHandler = (request: any) => Promise<CallToolResult>;

// Define a type for the handler map with an index signature
export interface CustomRpcHandlerMap {
  [key: string]: RpcHandler;
}

/**
 * Creates a map of custom RPC handlers that aren't part of the generated handlers
 * All handlers route through Dart VM backend
 */
export function createCustomRpcHandlerMap(
  rpcUtils: RpcUtilities,
  logger: Logger,
  handlePortParam: (request: CallToolRequest) => number
): CustomRpcHandlerMap {
  return {
    test_custom_ext: async (request: CallToolRequest) => {
      const port = handlePortParam(request);
      const result = await rpcUtils.callDartVm({
        method: "ext.mcp.toolkit.app_errors",
        dartVmPort: port,
        params: {
          count: 10,
        },
      });
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    },

    get_vm: async (request: CallToolRequest) => {
      const port = handlePortParam(request);
      const vm = await rpcUtils.getVmInfo(port);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(vm, null, 2),
          },
        ],
      };
    },

    hot_reload_flutter: async (request: CallToolRequest) => {
      // Route through Dart VM (callFlutterExtension now uses Dart VM)
      const result = await rpcUtils.callFlutterExtension(
        "ext.mcpdevtools.hotReload",
        {
          force: request.params.arguments?.force ?? false,
        }
      );

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(result, null, 2),
          },
        ],
      };
    },

    get_active_ports: async () => {
      const ports = await _getActivePorts(logger);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(ports, null, 2),
          },
        ],
      };
    },

    get_extension_rpcs: async (request: CallToolRequest) => {
      const port = handlePortParam(request);
      const { isolateId, isRawResponse = false } =
        (request.params.arguments as {
          isolateId?: string;
          isRawResponse?: boolean;
        }) || {};

      const vmInfo = await rpcUtils.getVmInfo(port);
      const isolates = vmInfo.isolates;

      if (isolateId) {
        const isolate = await rpcUtils.getIsolate(port, isolateId);

        if (isRawResponse) {
          return {
            content: [
              {
                type: "text",
                text: JSON.stringify(isolate, null, 2),
              },
            ],
          };
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(isolate.extensionRPCs || [], null, 2),
            },
          ],
        };
      }

      if (isRawResponse) {
        const allIsolates = await Promise.all(
          isolates.map((isolateRef: IsolateInfo) =>
            rpcUtils.getIsolate(port, isolateRef.id)
          )
        );
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(allIsolates, null, 2),
            },
          ],
        };
      }

      const allExtensions: string[] = [];
      for (const isolateRef of isolates) {
        const isolate = await rpcUtils.getIsolate(port, isolateRef.id);

        if (isolate.extensionRPCs) {
          allExtensions.push(...isolate.extensionRPCs);
        }
      }

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify([...new Set(allExtensions)], null, 2),
          },
        ],
      };
    },
  };
}

/**
 * Get active ports for Flutter/Dart processes via system commands
 * This is a utility function that doesn't depend on backend type
 */
async function _getActivePorts(logger: Logger): Promise<FlutterPort[]> {
  try {
    const { stdout } = await execAsync("lsof -i -P -n | grep LISTEN");
    const ports: FlutterPort[] = [];
    const lines = stdout.split("\n");

    for (const line of lines) {
      if (
        line.toLowerCase().includes("dart") ||
        line.toLowerCase().includes("flutter")
      ) {
        const parts = line.split(/\s+/);
        const pid = parts[1];
        const command = parts[0];
        const addressPart = parts[8];
        const portMatch = addressPart.match(/:(\d+)$/);

        if (portMatch) {
          ports.push({
            port: parseInt(portMatch[1], 10),
            pid,
            command,
          });
        }
      }
    }

    return ports;
  } catch (error) {
    logger.error("Error getting active ports:", { error });
    return [];
  }
}
