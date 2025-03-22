import { ErrorCode, McpError } from "@modelcontextprotocol/sdk/types.js";
import { exec } from "child_process";
import fs from "fs";
import yaml from "js-yaml";
import { promisify } from "util";
import { IsolateResponse, VMInfo } from "../types/types.js";
import {
  defaultDartVMPort,
  defaultFlutterExtensionPort,
} from "./flutter_inspector_server.js";
import { Logger } from "./logger.js";
import { RpcClient } from "./rpc_client.js";
import { RpcServer } from "./rpc_server.js";

type ConnectionDestination = "dart-vm" | "flutter-extension";
export const execAsync = promisify(exec);

/**
 * Utilities for handling RPC communication with Flutter applications
 */
export class RpcUtilities {
  private dartVmClient: RpcClient;
  private rpcServer: RpcServer | null = null;

  constructor(
    private readonly host: string = "localhost",
    private readonly logger: Logger
  ) {
    this.dartVmClient = new RpcClient();
  }

  /**
   * Start the RPC Server that can accept connections from Dart clients
   */
  async startRpcServer(
    port: number = defaultFlutterExtensionPort,
    path: string = "/ext-ws"
  ): Promise<RpcServer> {
    if (this.rpcServer) {
      this.logger.info(
        `RPC Server already running at ws://${this.host}:${port}${path}`
      );
      return this.rpcServer;
    }

    this.rpcServer = new RpcServer();

    // Add listener for client connections and set up tracking
    this.rpcServer.on("clientConnected", (clientId: string) => {
      this.logger.info(`Client connected: ${clientId}`);
    });
    const rpcServer = this.rpcServer;
    rpcServer.on("clientDisconnected", (clientId: string) => {
      rpcServer.clients.delete(clientId);
      if (rpcServer.lastClientId === clientId) {
        rpcServer.lastClientId =
          rpcServer.clients.size > 0
            ? Array.from(rpcServer.clients.keys())[0]
            : null;
      }
      this.logger.info(`Client disconnected: ${clientId}`);
    });

    await this.rpcServer.start(port, path);
    this.logger.info(`Started RPC Server at ws://${this.host}:${port}${path}`);
    return this.rpcServer;
  }

  /**
   * Send a message to a specific connected Dart client
   */
  async sendToDartClient(
    clientId: string,
    method: string,
    params: Record<string, unknown> = {}
  ): Promise<unknown> {
    if (!this.rpcServer) {
      throw new McpError(
        ErrorCode.InternalError,
        "RPC Server not started. Call startRpcServer first."
      );
    }

    return await this.rpcServer.callClientMethod(clientId, method, params);
  }

  /**
   * Connect to the Dart VM or ensure RPC server is running for Flutter extension
   */
  async connect(
    port: number,
    connectionDestination: ConnectionDestination
  ): Promise<void> {
    if (connectionDestination === "dart-vm") {
      await this.dartVmClient.connect(this.host, port, "/ws");
    } else {
      // For Flutter extension, we'll start the server if not already running
      if (!this.rpcServer) {
        await this.startRpcServer(port);
      }
    }
  }

  /**
   * Send a WebSocket request to the specified port
   */
  async sendWebSocketRequest(
    port: number,
    method: string,
    params: Record<string, unknown> = {},
    connectionDestination: ConnectionDestination = "dart-vm"
  ): Promise<unknown> {
    await this.connect(port, connectionDestination);

    if (connectionDestination === "dart-vm") {
      return this.dartVmClient.callMethod(method, params);
    } else {
      // For flutter-extension, use the RPC server if there's a connected client
      const clientId = this.rpcServer?.lastClientId;
      if (!clientId) {
        throw new McpError(
          ErrorCode.InternalError,
          "No Flutter clients connected to RPC server"
        );
      }

      return this.sendToDartClient(clientId, method, params);
    }
  }

  /**
   * Close all WebSocket connections
   */
  async closeAllConnections(): Promise<void> {
    this.dartVmClient.disconnect();

    if (this.rpcServer) {
      await this.rpcServer.stop();
      this.rpcServer = null;
    }
  }

  /**
   * Forwards a request to the Dart VM
   */
  async callDartVm(
    method: string,
    port: number,
    params: Record<string, unknown> = {}
  ): Promise<unknown> {
    try {
      const result = await this.sendWebSocketRequest(
        port,
        method,
        params,
        "dart-vm"
      );
      return result;
    } catch (error) {
      this.logger.error(`Error invoking Flutter method ${method}:`, error);
      throw error;
    }
  }

  /**
   * Forwards a request to the Flutter extension via the RPC server
   */
  async callFlutterExtension(
    method: string,
    port: number,
    params: Record<string, unknown> = {}
  ): Promise<unknown> {
    try {
      if (!this.rpcServer) {
        await this.startRpcServer(port);
      }

      // Wait for a client connection if none exists
      if (!this.rpcServer?.lastClientId) {
        throw new McpError(
          ErrorCode.InternalError,
          "No Flutter clients connected to RPC server. Ensure a client connects before making requests."
        );
      }

      // Send request to the last connected client
      return await this.sendToDartClient(
        this.rpcServer.lastClientId,
        method,
        params
      );
    } catch (error) {
      this.logger.error(`Error invoking Flutter method ${method}:`, error);
      throw error;
    }
  }

  /**
   * Get the Flutter isolate ID from the VM
   */
  async getFlutterIsolate(port: number): Promise<string> {
    const vmInfo = await this.getVmInfo(port);
    const isolates = vmInfo.isolates;

    // Find Flutter isolate by checking for Flutter extension RPCs
    for (const isolateRef of isolates) {
      const isolate = await this.getIsolate(port, isolateRef.id);

      // Check if this isolate has Flutter extensions
      const extensionRPCs = isolate.extensionRPCs || [];
      if (extensionRPCs.some((ext: string) => ext.startsWith("ext.flutter"))) {
        return isolateRef.id;
      }
    }

    throw new McpError(
      ErrorCode.InternalError,
      "No Flutter isolate found in the application"
    );
  }

  async getVmInfo(port: number): Promise<VMInfo> {
    const vmInfo = await this.callDartVm("getVM", port);
    return vmInfo as VMInfo;
  }

  async getIsolate(port: number, isolateId: string): Promise<IsolateResponse> {
    const isolate = await this.callDartVm("getIsolate", port, {
      isolateId,
    });
    return isolate as IsolateResponse;
  }

  /**
   * Verify that the Flutter app is running in debug mode
   */
  async verifyFlutterDebugMode(port: number): Promise<void> {
    const vmInfo = await this.getVmInfo(port);
    if (!vmInfo) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to get VM info from Flutter app on port ${port}`
      );
    }
  }

  /**
   * Wrap a promise response for MCP
   */
  async wrapResponse(promise: Promise<unknown>) {
    try {
      const result = await promise;
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (error: any) {
      return {
        content: [{ type: "text", text: `Error: ${error?.message}` }],
        isError: true,
      };
    }
  }

  /**
   * Load YAML tool configuration from a file path
   */
  loadYamlConfig(filePath: string): any {
    if (!fs.existsSync(filePath)) {
      throw new Error(`Cannot find YAML configuration at ${filePath}`);
    }

    const content = fs.readFileSync(filePath, "utf8");
    return yaml.load(content);
  }

  /**
   * Helper to extract port parameter from a request
   */
  handlePortParam(
    request: any,
    defaultPort: number = defaultDartVMPort
  ): number {
    const port = request.params.arguments?.port as number | undefined;
    return port || defaultPort;
  }
}
