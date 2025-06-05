import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequest,
  CallToolResult,
  ErrorCode,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";
import { Logger } from "../logger.js";
import { execAsync, RpcUtilities } from "../servers/rpc_utilities.js";
import { DynamicToolRegistry } from "../services/dynamic_registry/dynamic_tool_registry.js";
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
/**
 * Internal helper function to register a single tool
 */
function _registerTool(
  tool: any,
  sourceApp: string,
  dartVmPort: number,
  dynamicRegistry: DynamicToolRegistry,
  logger: Logger
): void {
  // Validate tool schema
  if (!tool.name || !tool.description) {
    throw new McpError(
      ErrorCode.InvalidParams,
      "Tool must have name and description"
    );
  }

  // Handle port changes
  dynamicRegistry.handlePortChange(sourceApp, dartVmPort);

  // Register the tool
  dynamicRegistry.registerTool(tool, sourceApp, dartVmPort);
}

/**
 * Internal helper function to register a single resource
 */
function _registerResource(
  resource: any,
  sourceApp: string,
  dartVmPort: number,
  dynamicRegistry: DynamicToolRegistry,
  logger: Logger
): void {
  // Validate resource schema
  if (!resource.uri || !resource.name) {
    throw new McpError(
      ErrorCode.InvalidParams,
      "Resource must have uri and name"
    );
  }

  // Handle port changes
  dynamicRegistry.handlePortChange(sourceApp, dartVmPort);

  // Register the resource
  dynamicRegistry.registerResource(resource, sourceApp, dartVmPort);
}

/**
 * Helper function to send tools list changed notification
 */
async function notifyToolsListChanged(
  server: Server,
  logger: Logger
): Promise<void> {
  try {
    await server.notification({
      method: "notifications/tools/list_changed",
    });
    logger.debug("[CustomRpcHandlers] Sent tools/list_changed notification");
  } catch (error) {
    logger.warn(
      "[CustomRpcHandlers] Failed to send tools/list_changed notification:",
      { error }
    );
  }
}

export function createCustomRpcHandlerMap(
  rpcUtils: RpcUtilities,
  logger: Logger,
  handlePortParam: (request: CallToolRequest) => number,
  dynamicRegistry: DynamicToolRegistry,
  server: Server
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

    // Internal function - not exposed as MCP tool
    _installTool: async (request: CallToolRequest): Promise<CallToolResult> => {
      if (!dynamicRegistry) {
        throw new McpError(
          ErrorCode.InternalError,
          "Dynamic registry not available"
        );
      }

      const { tool, tools, appId, sourceApp } = (request.params.arguments ||
        {}) as {
        tool?: any;
        tools?: any[];
        appId?: string;
        sourceApp?: string;
      };

      // Use the server's configured Dart VM port since it already has the connection
      const dartVmPort = rpcUtils.args.dartVMPort;

      // Handle parameter naming compatibility
      const actualSourceApp = sourceApp || appId;
      if (!actualSourceApp) {
        throw new McpError(
          ErrorCode.InvalidParams,
          "Either sourceApp or appId parameter is required"
        );
      }

      // Handle both single tool and batch tools registration
      const toolsToRegister = tools || (tool ? [tool] : []);
      if (toolsToRegister.length === 0) {
        throw new McpError(
          ErrorCode.InvalidParams,
          "Either tool or tools parameter is required"
        );
      }

      try {
        // Register all tools
        for (const toolToRegister of toolsToRegister) {
          // Validate tool schema
          if (!toolToRegister.name || !toolToRegister.description) {
            throw new McpError(
              ErrorCode.InvalidParams,
              "Tool must have name and description"
            );
          }

          // Handle port changes
          dynamicRegistry.handlePortChange(actualSourceApp, dartVmPort);

          // Register the tool
          dynamicRegistry.registerTool(
            toolToRegister,
            actualSourceApp,
            dartVmPort
          );
        }

        logger.info(
          `[InstallTool] Successfully registered ${toolsToRegister.length} tools from ${actualSourceApp}:${dartVmPort}`
        );

        // Notify MCP clients that the tools list has changed
        if (server && toolsToRegister.length > 0) {
          await notifyToolsListChanged(server, logger);
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  success: true,
                  message: `${toolsToRegister.length} tool(s) installed successfully`,
                  toolNames: toolsToRegister.map((t) => t.name),
                  sourceApp: actualSourceApp,
                  dartVmPort,
                  registeredAt: new Date().toISOString(),
                },
                null,
                2
              ),
            },
          ],
        };
      } catch (error) {
        logger.error(`[InstallTool] Failed to install tool:`, { error });
        throw new McpError(
          ErrorCode.InternalError,
          `Failed to install tool: ${error}`
        );
      }
    },

    // Internal function - not exposed as MCP tool
    _installResource: async (
      request: CallToolRequest
    ): Promise<CallToolResult> => {
      if (!dynamicRegistry) {
        throw new McpError(
          ErrorCode.InternalError,
          "Dynamic registry not available"
        );
      }

      const { resource, resources, appId, sourceApp } = (request.params
        .arguments || {}) as {
        resource?: any;
        resources?: any[];
        appId?: string;
        sourceApp?: string;
      };

      // Use the server's configured Dart VM port since it already has the connection
      const dartVmPort = rpcUtils.args.dartVMPort;

      // Handle parameter naming compatibility
      const actualSourceApp = sourceApp || appId;
      if (!actualSourceApp) {
        throw new McpError(
          ErrorCode.InvalidParams,
          "Either sourceApp or appId parameter is required"
        );
      }

      // Handle both single resource and batch resources registration
      const resourcesToRegister = resources || (resource ? [resource] : []);
      if (resourcesToRegister.length === 0) {
        throw new McpError(
          ErrorCode.InvalidParams,
          "Either resource or resources parameter is required"
        );
      }

      try {
        // Register all resources
        for (const resourceToRegister of resourcesToRegister) {
          // Validate resource schema
          if (!resourceToRegister.uri || !resourceToRegister.name) {
            throw new McpError(
              ErrorCode.InvalidParams,
              "Resource must have uri and name"
            );
          }

          // Handle port changes
          dynamicRegistry.handlePortChange(actualSourceApp, dartVmPort);

          // Register the resource
          dynamicRegistry.registerResource(
            resourceToRegister,
            actualSourceApp,
            dartVmPort
          );
        }

        logger.info(
          `[InstallResource] Successfully registered ${resourcesToRegister.length} resources from ${actualSourceApp}:${dartVmPort}`
        );

        // Notify MCP clients that the tools list has changed
        if (server && resourcesToRegister.length > 0) {
          await notifyToolsListChanged(server, logger);
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  success: true,
                  message: `${resourcesToRegister.length} resource(s) installed successfully`,
                  resourceUris: resourcesToRegister.map((r) => r.uri),
                  sourceApp: actualSourceApp,
                  dartVmPort,
                  registeredAt: new Date().toISOString(),
                },
                null,
                2
              ),
            },
          ],
        };
      } catch (error) {
        logger.error(`[InstallResource] Failed to install resource:`, {
          error,
        });
        throw new McpError(
          ErrorCode.InternalError,
          `Failed to install resource: ${error}`
        );
      }
    },

    autoRegisterDynamics: async (
      request: CallToolRequest
    ): Promise<CallToolResult> => {
      if (!dynamicRegistry) {
        throw new McpError(
          ErrorCode.InternalError,
          "Dynamic registry not available"
        );
      }

      try {
        logger.info(
          "[AutoRegisterDynamics] Triggering manual registration via AutomaticRegistrationManager"
        );

        // Get the AutomaticRegistrationManager instance from the server context
        // Since we don't have direct access to it here, we'll call the registration directly
        // This maintains backward compatibility while using the new event-driven system

        const dartVmPort = rpcUtils.args.dartVMPort;

        // Call the Flutter app's registerDynamics service extension
        const result = await rpcUtils.callDartVm({
          method: "ext.mcp.toolkit.registerDynamics",
          dartVmPort,
          params: {},
        });

        const {
          tools = [],
          resources = [],
          appId,
        } = result as {
          tools?: any[];
          resources?: any[];
          appId?: string;
        };

        if (!appId) {
          return {
            content: [
              {
                type: "text",
                text: JSON.stringify(
                  {
                    success: false,
                    message: "Flutter app did not provide appId",
                    trigger: "auto_register_dynamics",
                  },
                  null,
                  2
                ),
              },
            ],
          };
        }

        // Clear existing registrations for this app to avoid duplicates
        dynamicRegistry.clearAppRegistrations(appId);

        const registeredTools: string[] = [];
        const registeredResources: string[] = [];

        // Register all tools
        for (const tool of tools) {
          try {
            _registerTool(tool, appId, dartVmPort, dynamicRegistry, logger);
            registeredTools.push(tool.name);
          } catch (error) {
            logger.warn(
              `[AutoRegisterDynamics] Failed to register tool ${tool.name}:`,
              { error }
            );
          }
        }

        // Register all resources
        for (const resource of resources) {
          try {
            _registerResource(
              resource,
              appId,
              dartVmPort,
              dynamicRegistry,
              logger
            );
            registeredResources.push(resource.uri);
          } catch (error) {
            logger.warn(
              `[AutoRegisterDynamics] Failed to register resource ${resource.uri}:`,
              { error }
            );
          }
        }

        logger.info(
          `[AutoRegisterDynamics] Successfully registered ${tools.length} tools and ${resources.length} resources from ${appId}`
        );

        // Notify MCP clients that the tools list has changed
        if (server) {
          await notifyToolsListChanged(server, logger);
        }

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  success: true,
                  message: `auto-registration completed: ${tools.length} tool(s) and ${resources.length} resource(s) registered`,
                  toolNames: registeredTools,
                  resourceUris: registeredResources,
                  sourceApp: appId,
                  dartVmPort,
                  trigger: "auto_register_dynamics",
                  registeredAt: new Date().toISOString(),
                  note: "This tool manually triggers registration. Automatic registration via event streaming is also active in the background.",
                },
                null,
                2
              ),
            },
          ],
        };
      } catch (error) {
        logger.warn(`[AutoRegisterDynamics] Manual auto-registration failed:`, {
          error,
        });
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  success: false,
                  message: `auto-registration failed: ${error}`,
                  trigger: "auto_register_dynamics",
                },
                null,
                2
              ),
            },
          ],
        };
      }
    },

    listDynamicRegistrations: async (
      request: CallToolRequest
    ): Promise<CallToolResult> => {
      if (!dynamicRegistry) {
        throw new McpError(
          ErrorCode.InternalError,
          "Dynamic registry not available"
        );
      }

      const { type = "all" } = (request.params.arguments || {}) as {
        type?: "tools" | "resources" | "all";
      };

      try {
        const stats = dynamicRegistry.getStats();
        const tools =
          type === "resources" ? [] : dynamicRegistry.getDynamicTools();
        const resources =
          type === "tools" ? [] : dynamicRegistry.getDynamicResources();

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  success: true,
                  statistics: stats,
                  tools: tools.map((tool) => ({
                    name: tool.name,
                    description: tool.description,
                    entry: dynamicRegistry.getToolEntry(tool.name),
                  })),
                  resources: resources.map((resource) => ({
                    uri: resource.uri,
                    name: resource.name,
                    description: resource.description,
                    entry: dynamicRegistry.getResourceEntry(resource.uri),
                  })),
                },
                null,
                2
              ),
            },
          ],
        };
      } catch (error) {
        logger.error(
          `[ListDynamicRegistrations] Failed to list registrations:`,
          { error }
        );
        throw new McpError(
          ErrorCode.InternalError,
          `Failed to list registrations: ${error}`
        );
      }
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
