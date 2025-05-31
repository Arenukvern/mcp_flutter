import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CommandLineConfig } from "../index.js";
import { Logger } from "../logger.js";
import { ResourcesHandlers } from "../resources/resource_handlers.js";
import { FlutterRpcHandlers } from "../tools/index.js";
import { ToolsHandlers } from "../tools/tools_handlers.js";
import { RpcUtilities } from "./rpc_utilities.js";

/**
 * Main Flutter Inspector MCP Server
 * Currently configured for Dart VM backend only, with extension points for future backends
 */
export class FlutterInspectorServer {
  // Declare server with any type to work around type issues
  private server: McpServer;
  private port: number;
  private rpcUtils: RpcUtilities;
  private logger: Logger;
  private resources = new ResourcesHandlers();
  private tools: ToolsHandlers;

  constructor(private readonly args: CommandLineConfig) {
    this.port = args.port;
    this.server = new McpServer(
      {
        name: "flutter-inspector",
        version: "0.1.0",
      },
      {
        capabilities: {
          logging: {},
          tools: {
            listChanged: true,
          },
          prompts: {},
          resources: {},
        },
      }
    );
    this.logger = new Logger(
      "flutter-inspector",
      args.logLevel,
      this.server.server
    );
    this.rpcUtils = new RpcUtilities(this.logger, this.args);
    this.tools = new ToolsHandlers(this.logger);

    this.setupErrorHandling();
  }

  private setupErrorHandling() {
    this.server.server.onerror = (error: Error) =>
      this.logger.error("[MCP Error]", { error });

    process.on("SIGINT", async () => {
      await this.rpcUtils.closeAllConnections();
      await this.server.close();
      process.exit(0);
    });
  }

  /**
   * Set up handlers for tools and resources
   * TODO: Add dependency injection for backend-specific handlers in the future
   */
  private async setHandlers() {
    try {
      this.logger.info("[FlutterInspectorServer] Starting setHandlers");
      const server = this.server.server;

      // Create RPC handlers - currently using Dart VM only
      const rpcHandlers = new FlutterRpcHandlers(
        this.rpcUtils,
        (request) => this.rpcUtils.handlePortParam(request) // Simplified since only Dart VM supported
      );

      this.logger.info("[FlutterInspectorServer] Created RPC handlers");

      // Set up tool handlers first to initialize dynamic registry
      await this.tools.setHandlers(
        server,
        this.rpcUtils,
        this.logger,
        rpcHandlers,
        this.resources
      );

      this.logger.info("[FlutterInspectorServer] Set up tool handlers");

      // Set up resource handlers with access to dynamic registry
      this.resources.setHandlers(
        server,
        this.rpcUtils,
        rpcHandlers,
        this.tools.getDynamicRegistry()
      );

      this.logger.info("[FlutterInspectorServer] Set up resource handlers");
    } catch (error) {
      this.logger.error("Error setting up tool handlers:", { error });
      throw error;
    }
  }

  async run() {
    // 1. First initialize async resources
    const transport = new StdioServerTransport();

    // 2. Start servers in parallel with proper cleanup
    try {
      // Setup the MCP transport
      await this.server.connect(transport);

      // Connect to Dart VM backend
      // Note: Connection errors are handled gracefully and don't crash the server
      await this.rpcUtils.connect(this.args.dartVMPort);

      // Set up handlers after connections are established
      await this.setHandlers();

      // Setup coordinated shutdown
      const cleanup = async () => {
        await this.rpcUtils.closeAllConnections();
        await transport.close();
      };

      process.on("SIGINT", cleanup);
      process.on("SIGTERM", cleanup);

      this.logger.info(`
        🚀 Flutter Inspector MCP Server Ready
        📡 MCP Server: stdio mode (port ${this.port})
        🎯 Dart VM Backend: ws://${this.args.dartVMHost}:${this.args.dartVMPort}/ws
        💡 Backend Architecture: Ready for future extension via plugin system
      `);
    } catch (error) {
      this.logger.error("Failed to start server:", { error });
      process.exit(1);
    }
  }

  /**
   * TODO: Future extension point for backend registration
   * Example usage: server.registerBackend('grpc', new GrpcBackendClient(...))
   */
  // registerBackend(name: string, client: IBackendClient): void {
  //   this.backendClients.set(name, client);
  // }
}
