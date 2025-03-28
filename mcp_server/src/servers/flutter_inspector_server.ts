import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";
import { Logger, LogLevel } from "flutter_mcp_forwarding_server";
import path from "path";
import { fileURLToPath } from "url";
import { CommandLineConfig } from "../index.js";
import { createCustomRpcHandlerMap } from "./create_custom_rpc_handler_map.js";
import { createRpcHandlerMap } from "./create_rpc_handler_map.js";
import {
  FlutterRpcHandlers,
  RpcToolName,
} from "./flutter_rpc_handlers.generated.js";
import { RpcUtilities } from "./rpc_utilities.js";

// Get the directory name in ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export class FlutterInspectorServer {
  // Declare server with any type to work around type issues
  private server: McpServer;
  private port: number;
  private logLevel: LogLevel;
  private rpcUtils: RpcUtilities;
  private logger: Logger;

  constructor(private readonly args: CommandLineConfig) {
    this.port = args.port;
    this.logLevel = args.logLevel;
    this.logger = new Logger(this.logLevel);
    this.rpcUtils = new RpcUtilities(this.logger, this.args);

    this.server = new McpServer({
      name: "flutter-inspector",
      version: "0.1.0",
    });

    this.setupToolHandlers();
    this.setupErrorHandling();
  }

  private setupErrorHandling() {
    this.server.server.onerror = (error: Error) =>
      this.logger.error("[MCP Error]", error);

    process.on("SIGINT", async () => {
      await this.rpcUtils.closeAllConnections();
      await this.server.close();
      process.exit(0);
    });
  }

  private setupToolHandlers() {
    const serverToolsFlutterPath = path.join(
      __dirname,
      "server_tools_flutter.yaml"
    );
    const serverToolsCustomPath = path.join(
      __dirname,
      "server_tools_custom.yaml"
    );
    try {
      // Load tools configuration
      const serverToolsFlutter = this.rpcUtils.loadYamlConfig(
        serverToolsFlutterPath
      );
      const serverToolsCustom = this.rpcUtils.loadYamlConfig(
        serverToolsCustomPath
      );

      this.server.server.setRequestHandler(
        ListToolsRequestSchema,
        async () => ({
          tools: [...serverToolsFlutter.tools, ...serverToolsCustom.tools],
        })
      );

      const rpcHandlers = new FlutterRpcHandlers(
        this.rpcUtils,
        (request, connectionDestination) =>
          this.rpcUtils.handlePortParam(request, connectionDestination)
      );

      // Use the generated function to create the handler map
      const handlerMap = createRpcHandlerMap(rpcHandlers);

      // Get custom handlers
      const customHandlerMap = createCustomRpcHandlerMap(
        this.rpcUtils,
        this.logger,
        (request, connectionDestination) =>
          this.rpcUtils.handlePortParam(request, connectionDestination)
      );

      this.server.server.setRequestHandler(
        CallToolRequestSchema,
        async (request: any) => {
          const toolName = request.params.name;
          const generatedHandler:
            | ((request: any) => Promise<unknown>)
            | undefined = handlerMap[toolName as RpcToolName];
          // Check generated handlers first
          if (generatedHandler) return generatedHandler(request);

          // Then check custom handlers
          if (customHandlerMap[toolName]) {
            return customHandlerMap[toolName](request);
          }

          throw new McpError(
            ErrorCode.MethodNotFound,
            `Unknown tool: ${request.params.name}`
          );
        }
      );
    } catch (error) {
      this.logger.error("Error setting up tool handlers:", error);
      throw error;
    }
  }

  async run() {
    // 1. First initialize async resources
    const transport = new StdioServerTransport();

    // 2. Start servers in parallel with proper cleanup
    try {
      // Setup the transport first
      await this.server.connect(transport);

      // Now try to connect to the services - these connections are now resilient to failure
      await this.rpcUtils.connect(this.args.dartVMPort, "dart-vm");
      await this.rpcUtils.connect(
        this.args.forwardingServerPort,
        "flutter-extension"
      );

      // 3. Add coordinated shutdown
      const cleanup = async () => {
        await this.rpcUtils.closeAllConnections();
        await transport.close();
      };

      process.on("SIGINT", cleanup);
      process.on("SIGTERM", cleanup);

      this.logger.info(`
        MCP Server: Ready on stdio (port ${this.port})
        RPC Server: Attempting to connect to ws://${this.args.dartVMHost}:${this.args.dartVMPort}/ws
        Forwarding Client: Attempting to connect to ws://${this.args.forwardingServerHost}:${this.args.forwardingServerPort}/forward
      `);
    } catch (error) {
      this.logger.error("Failed to start server:", error);
      process.exit(1);
    }
  }
}
