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
  private tools = new ToolsHandlers();

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
          tools: {},
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

    this.setHandlers();
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
  private setHandlers() {
    try {
      const server = this.server.server;

      // Create RPC handlers - currently using Dart VM only
      const rpcHandlers = new FlutterRpcHandlers(
        this.rpcUtils,
        (request) => this.rpcUtils.handlePortParam(request) // Simplified since only Dart VM supported
      );

      // Set up resource and tool handlers
      this.resources.setHandlers(server, this.rpcUtils, rpcHandlers);
      this.tools.setHandlers(
        server,
        this.rpcUtils,
        this.logger,
        rpcHandlers,
        this.resources
      );
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
