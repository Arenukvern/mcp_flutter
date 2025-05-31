import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
  Request,
  Result,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import path from "path";
import { fileURLToPath } from "url";
import { Env } from "../index.js";
import { Logger } from "../logger.js";
import { ResourcesHandlers } from "../resources/resource_handlers.js";
import { RpcUtilities } from "../servers/rpc_utilities.js";
import { AutomaticRegistrationManager } from "../services/dynamic_registry/automatic_registration_manager.js";
import { DynamicToolRegistry } from "../services/dynamic_registry/dynamic_tool_registry.js";
import { createCustomRpcHandlerMap } from "./create_custom_rpc_handler_map.js";
import { createRpcHandlerMap } from "./create_rpc_handler_map.js";
import {
  FlutterRpcHandlers,
  RpcToolName,
} from "./flutter_rpc_handlers.generated.js";

// Get the directory name in ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Handles tool registration and routing for the Flutter Inspector
 * All tools route through Dart VM backend
 */
export class ToolsHandlers {
  private dynamicRegistry: DynamicToolRegistry;
  private autoRegistrationManager: AutomaticRegistrationManager | null = null;

  constructor(logger: Logger) {
    this.dynamicRegistry = new DynamicToolRegistry(logger);
  }

  /**
   * Get the dynamic registry instance for use by other handlers
   */
  public getDynamicRegistry(): DynamicToolRegistry {
    return this.dynamicRegistry;
  }

  public async setHandlers(
    server: Server,
    rpcUtils: RpcUtilities,
    logger: Logger,
    rpcHandlers: FlutterRpcHandlers,
    resourcesHandlers: ResourcesHandlers
  ) {
    const serverToolsFlutterPath = path.join(
      __dirname,
      "server_tools_flutter.yaml"
    );
    const serverToolsCustomPath = path.join(
      __dirname,
      "server_tools_custom.yaml"
    );

    // Load tools configuration from YAML files
    const serverToolsFlutter: { tools: Tool[] } = rpcUtils.loadYamlConfig(
      serverToolsFlutterPath
    );
    const serverToolsCustom: { tools: Tool[] } = rpcUtils.loadYamlConfig(
      serverToolsCustomPath
    );

    // Get static tool schemes (these don't change)
    const staticToolSchemes: Tool[] = [
      ...serverToolsFlutter.tools,
      ...serverToolsCustom.tools,
      ...resourcesHandlers.getToolSchemes(rpcUtils),
    ];

    // Register list tools handler - dynamically fetch tools on each request
    server.setRequestHandler(ListToolsRequestSchema, async () => {
      // Combine static tools with current dynamic tools
      const allToolSchemes: Tool[] = [
        ...staticToolSchemes,
        ...this.dynamicRegistry.getDynamicTools(),
      ];

      // Filter tools based on environment and capabilities
      const filteredToolSchemes = allToolSchemes.filter((tool) => {
        if (rpcUtils.args.env === Env.Production) {
          if (tool.name.includes("dump") && !rpcUtils.args.areDumpSupported) {
            return false;
          }
          return true;
        }
        if (rpcUtils.args.env === Env.Development) {
          return true;
        }
        return false;
      });

      return {
        tools: filteredToolSchemes,
      };
    });

    // Create handler maps for different tool types
    const handlerMap = createRpcHandlerMap(rpcHandlers);

    // Get custom handlers (all using Dart VM backend)
    const customHandlerMap = createCustomRpcHandlerMap(
      rpcUtils,
      logger,
      (request) => rpcUtils.handlePortParam(request), // Simplified since only Dart VM supported
      this.dynamicRegistry,
      server
    );

    // Get resource-based tool handlers
    const customResourceHandlerMap = resourcesHandlers.getTools(
      rpcUtils,
      rpcHandlers
    );

    // Register call tool handler with routing logic
    server.setRequestHandler(
      CallToolRequestSchema,
      async (request: Request): Promise<Result> => {
        const toolName = request.params?.name;
        if (!toolName || typeof toolName !== "string") {
          throw new McpError(
            ErrorCode.MethodNotFound,
            `Unknown tool: ${request.params?.name}`
          );
        }

        const generatedHandler = handlerMap[toolName as RpcToolName];

        // Check generated handlers first
        if (generatedHandler) return generatedHandler(request);

        // Then check custom handlers
        if (customHandlerMap[toolName]) {
          return customHandlerMap[toolName](request);
        }

        // Check dynamic tools
        if (this.dynamicRegistry.isDynamicTool(toolName)) {
          return this.handleDynamicTool(toolName, request, rpcUtils);
        }

        // Finally check resource-based handlers
        if (customResourceHandlerMap[toolName]) {
          return customResourceHandlerMap[toolName](request);
        }

        throw new McpError(
          ErrorCode.MethodNotFound,
          `Unregistered tool: ${toolName}`
        );
      }
    );

    // Initialize automatic registration system
    this.autoRegistrationManager = new AutomaticRegistrationManager(
      logger,
      rpcUtils,
      this.dynamicRegistry,
      server
    );

    // Start automatic registration (don't await to avoid blocking server startup)
    this.autoRegistrationManager.initialize().catch((error) => {
      logger.warn(
        "[ToolsHandlers] Failed to initialize automatic registration:",
        { error }
      );
    });
  }

  /**
   * Handle dynamic tool execution by routing to the appropriate Flutter app
   */
  private async handleDynamicTool(
    toolName: string,
    request: Request,
    rpcUtils: RpcUtilities
  ): Promise<Result> {
    const toolEntry = this.dynamicRegistry.getToolEntry(toolName);
    if (!toolEntry) {
      throw new McpError(
        ErrorCode.MethodNotFound,
        `Dynamic tool not found: ${toolName}`
      );
    }

    try {
      // Route the call to the Flutter app that registered this tool
      const result = await rpcUtils.callDartVm({
        method: `ext.mcp.toolkit.${toolName}`,
        dartVmPort: toolEntry.dartVmPort,
        params: (request.params?.arguments as Record<string, unknown>) || {},
      });

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(result, null, 2),
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to execute dynamic tool ${toolName}: ${error}`
      );
    }
  }
}
