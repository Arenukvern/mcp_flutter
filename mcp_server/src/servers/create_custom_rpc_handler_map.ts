import { Logger } from "forwarding-server";
import { FlutterPort, IsolateInfo } from "../types/types.js";
import {
  ConnectionDestination,
  execAsync,
  RpcUtilities,
} from "./rpc_utilities.js";

// Define a type for the handler function
type RpcHandler = (request: any) => Promise<any>;

// Define a type for the handler map with an index signature
interface CustomRpcHandlerMap {
  [key: string]: RpcHandler;
}

/**
 * Creates a map of custom RPC handlers that aren't part of the generated handlers
 */
export function createCustomRpcHandlerMap(
  rpcUtils: RpcUtilities,
  logger: Logger,
  handlePortParam: (
    request: any,
    connectionDestination: ConnectionDestination
  ) => number
): CustomRpcHandlerMap {
  return {
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
    get_extension_rpcs: async (request: any) => {
      const port = handlePortParam(request, "dart-vm");
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
 * Get active ports for Flutter/Dart processes
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
    logger.error("Error getting active ports:", error);
    return [];
  }
}
