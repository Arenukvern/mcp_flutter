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
  public setHandlers(
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

    // Combine all tool schemes
    const toolSchemes: Tool[] = [
      ...serverToolsFlutter.tools,
      ...serverToolsCustom.tools,
      ...resourcesHandlers.getToolSchemes(rpcUtils),
    ];

    // Filter tools based on environment and capabilities
    const filteredToolSchemes = toolSchemes.filter((tool) => {
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

    // Register list tools handler
    server.setRequestHandler(ListToolsRequestSchema, async () => {
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
      (request) => rpcUtils.handlePortParam(request) // Simplified since only Dart VM supported
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
  }
}
