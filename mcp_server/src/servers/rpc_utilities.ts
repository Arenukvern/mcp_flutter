import { ErrorCode, McpError } from "@modelcontextprotocol/sdk/types.js";
import { exec } from "child_process";
import { ClientType, ForwardingClient, Logger } from "forwarding-server";
import fs from "fs";
import yaml from "js-yaml";
import { promisify } from "util";
import { IsolateResponse, VMInfo } from "../types/types.js";
import { defaultDartVMPort } from "./flutter_inspector_server.js";
import { RpcClient } from "./rpc_client.js";

type ConnectionDestination = "dart-vm" | "flutter-extension";
export const execAsync = promisify(exec);

/**
 * Utilities for handling RPC communication with Flutter applications
 */
export class RpcUtilities {
  private dartVmClient: RpcClient;
  private forwardingClient: ForwardingClient;
  private cachedFlutterIsolate: string | null = null;

  constructor(
    private readonly host: string = "localhost",
    private readonly logger: Logger
  ) {
    this.dartVmClient = new RpcClient(logger);
    this.forwardingClient = new ForwardingClient(
      ClientType.INSPECTOR,
      logger,
      "flutter-inspector"
    );

    // Set up event listeners for debugging forwarding client
    this.forwardingClient.on("connected", () => {
      this.logger.info(
        "[ForwardingClient] Successfully connected to forwarding server"
      );
    });

    this.forwardingClient.on("disconnected", () => {
      this.logger.warn(
        "[ForwardingClient] Disconnected from forwarding server"
      );
    });

    this.forwardingClient.on("error", (error) => {
      this.logger.error("[ForwardingClient] Connection error:", error);
    });

    this.forwardingClient.on("message", (message) => {
      try {
        const parsedMessage =
          typeof message === "string" ? JSON.parse(message) : message;
        const messageId = parsedMessage.id || "unknown";
        const messageMethod = parsedMessage.method || "unknown";
        const isResponse =
          !parsedMessage.method && parsedMessage.hasOwnProperty("result");

        if (isResponse) {
          this.logger.debug(
            `[ForwardingClient] Received RESPONSE for ID: ${messageId}:`
          );
        } else {
          this.logger.debug(
            `[ForwardingClient] Received REQUEST for method: ${messageMethod} with ID: ${messageId}:`
          );
        }

        // For inspector methods, log more details
        if (messageMethod && messageMethod.includes("inspector")) {
          this.logger.debug(
            `[ForwardingClient][INSPECTOR] Full message:`,
            JSON.stringify(parsedMessage, null, 2)
          );
        }
      } catch (e) {
        this.logger.debug(
          "[ForwardingClient] Received message (unable to parse):",
          message
        );
      }
    });
  }

  /**
   * Connect to the Dart VM or Forwarding Server
   */
  async connect(
    port: number,
    connectionDestination: ConnectionDestination
  ): Promise<void> {
    try {
      if (connectionDestination === "dart-vm") {
        await this.dartVmClient.connect(this.host, port, "/ws");
      } else {
        this.logger.info(
          `[ForwardingClient] Attempting to connect to ws://${this.host}:${port}/forward as clientType=${ClientType.INSPECTOR}, clientId=flutter-inspector`
        );
        await this.forwardingClient.connect(this.host, port, "/forward");

        // Register a test method handler to verify bidirectional communication
        this.forwardingClient.registerMethod(
          "flutter.test.ping",
          async (params) => {
            this.logger.info(
              `[ForwardingClient] Received ping with params:`,
              params
            );
            return {
              success: true,
              timestamp: Date.now(),
              message: "MCP Server is responsive",
            };
          }
        );

        // Register a specific handler for screenshot method to debug issues
        this.forwardingClient.registerMethod(
          "ext.flutter.inspector.screenshot",
          async (params) => {
            this.logger.info(
              `[ForwardingClient][SCREENSHOT] Received screenshot request with params:`,
              params
            );
            // Just pass this through to Flutter but log it thoroughly
            try {
              // We don't actually handle it here, this is just for logging
              // The real handling happens in the Flutter client
              this.logger.info(
                `[ForwardingClient][SCREENSHOT] Successfully logged screenshot request`
              );
              return null; // Let the normal flow continue
            } catch (err) {
              this.logger.error(
                `[ForwardingClient][SCREENSHOT] Error handling screenshot:`,
                err
              );
              throw err;
            }
          }
        );

        // Send a test message after connecting successfully
        if (this.forwardingClient.isConnected()) {
          setTimeout(async () => {
            try {
              this.logger.info(
                `[ForwardingClient] Sending test message to Flutter clients`
              );
              const result = await this.forwardingClient.callMethod(
                "flutter.test.ping",
                {
                  timestamp: Date.now(),
                  source: "mcp-server",
                }
              );
              this.logger.info(
                `[ForwardingClient] Received response to test ping:`,
                result
              );
            } catch (err) {
              this.logger.error(
                `[ForwardingClient] Error sending test message:`,
                err
              );
            }
          }, 2000);
        } else {
          this.logger.warn(
            `[ForwardingClient] Connection reported as not established after connect() completed`
          );
        }
      }
    } catch (error) {
      // Log the error but don't crash the application
      this.logger.error(
        `Failed to connect to ${connectionDestination} on port ${port}:`,
        error
      );
      // Don't rethrow the error to allow the application to continue
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
    try {
      await this.connect(port, connectionDestination);

      if (connectionDestination === "dart-vm") {
        return this.dartVmClient.callMethod(method, params);
      } else {
        return this.forwardingClient.callMethod(method, params);
      }
    } catch (error) {
      this.logger.error(`WebSocket request failed (${method}):`, error);
      return null; // Return null instead of propagating the error
    }
  }

  /**
   * Close all WebSocket connections
   */
  async closeAllConnections(): Promise<void> {
    this.dartVmClient.disconnect();
    this.forwardingClient.disconnect();
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
      const flutterIsolateId = await this.getFlutterIsolateId(port);
      const result = await this.sendWebSocketRequest(
        port,
        method,
        { ...params, isolateId: flutterIsolateId },
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
      const requestId = `req_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
      this.logger.info(
        `[ForwardingClient][${requestId}] Calling Flutter extension method: ${method} with params:`,
        params
      );

      if (!this.forwardingClient.isConnected()) {
        this.logger.warn(
          `[ForwardingClient][${requestId}] Not connected when attempting to call ${method}, trying to reconnect...`
        );
        await this.connect(port, "flutter-extension");
      }

      // Check again after reconnection attempt
      if (!this.forwardingClient.isConnected()) {
        this.logger.error(
          `[ForwardingClient][${requestId}] Still not connected after reconnection attempt, method call ${method} will likely fail`
        );
      } else {
        this.logger.info(
          `[ForwardingClient][${requestId}] Connected and ready to send ${method}`
        );
      }

      // Override sendWebSocketRequest to directly use the forwardingClient for better tracking
      if (method.includes("ext.flutter.inspector")) {
        this.logger.debug(
          `[ForwardingClient][${requestId}] Using direct forwardingClient.callMethod for inspector method: ${method}`
        );
        try {
          const result = await this.forwardingClient.callMethod(method, params);
          this.logger.info(
            `[ForwardingClient][${requestId}] Method ${method} completed successfully`
          );
          this.logger.debug(`[ForwardingClient][${requestId}] Result:`, result);
          return result;
        } catch (error) {
          this.logger.error(
            `[ForwardingClient][${requestId}] Direct call failed for ${method}:`,
            error
          );
          throw error;
        }
      } else {
        const result = await this.sendWebSocketRequest(
          port,
          method,
          params,
          "flutter-extension"
        );

        this.logger.info(
          `[ForwardingClient][${requestId}] Method ${method} result:`,
          result
        );
        return result;
      }
    } catch (error) {
      const errorId = `err_${Date.now()}`;
      this.logger.error(
        `[ForwardingClient][${errorId}] Error invoking Flutter method ${method}:`,
        error
      );
      // Create a more detailed error object with context
      const contextError = new Error(
        `Error calling ${method}: ${
          error instanceof Error ? error.message : String(error)
        }`
      );
      (contextError as any).originalError = error;
      (contextError as any).method = method;
      (contextError as any).params = params;
      throw contextError;
    }
  }
  /**
   * Get the Flutter isolate ID from the VM
   */
  async getFlutterIsolateId(port: number): Promise<string> {
    if (this.cachedFlutterIsolate) {
      return this.cachedFlutterIsolate;
    }

    const vmInfo = await this.getVmInfo(port);
    const isolates = vmInfo.isolates;

    // Find Flutter isolate by checking for Flutter extension RPCs
    for (const isolateRef of isolates) {
      const isolate = await this.getIsolate(port, isolateRef.id);

      // Check if this isolate has Flutter extensions
      const extensionRPCs = isolate.extensionRPCs || [];
      if (extensionRPCs.some((ext: string) => ext.startsWith("ext.flutter"))) {
        this.cachedFlutterIsolate = isolateRef.id;
        return this.cachedFlutterIsolate;
      }
    }

    throw new McpError(
      ErrorCode.InternalError,
      "No Flutter isolate found in the application"
    );
  }

  async getVmInfo(port: number): Promise<VMInfo> {
    const vmInfo = await this.sendWebSocketRequest(port, "getVM");
    return vmInfo as VMInfo;
  }

  async getIsolate(port: number, isolateId: string): Promise<IsolateResponse> {
    const isolate = await this.sendWebSocketRequest(port, "getIsolate", {
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
      this.logger.debug(`Wrap response: ${JSON.stringify(result, null, 2)}`);
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
