import { ErrorCode, McpError } from "@modelcontextprotocol/sdk/types.js";
import { exec } from "child_process";
import fs from "fs";
import yaml from "js-yaml";
import { promisify } from "util";
import { CommandLineConfig } from "../index.js";
import { Logger } from "../logger.js";
import { IsolateResponse, VMInfo } from "../types/types.js";
import { RpcClient } from "./rpc_client.js";

export const execAsync = promisify(exec);

export type RpcToolResponseType = {
  content: { type: string; text: string }[];
  isError?: boolean;
};

export type FlutterExtensionResponse = {
  success: boolean;
  data: unknown;
  error?: string;
};

/**
 * Utilities for handling RPC communication with Flutter applications
 * Currently supports only Dart VM backend, designed for future extensibility
 */
export class RpcUtilities {
  private dartVmClient: RpcClient;

  constructor(
    private readonly logger: Logger,
    public readonly args: CommandLineConfig
  ) {
    this.dartVmClient = new RpcClient(logger);
  }

  /**
   * Connect to the Dart VM backend
   * @param dartVmPort - The port of the Dart VM, if undefined, the default port will be used
   */
  async connect(dartVmPort: number | undefined): Promise<void> {
    try {
      await this.dartVmClient.connect(
        this.args.dartVMHost,
        dartVmPort || this.args.dartVMPort,
        "/ws"
      );
      this.logger.info(
        `[DartVM] Successfully connected to ${this.args.dartVMHost}:${
          dartVmPort || this.args.dartVMPort
        }`
      );
    } catch (error) {
      this.logger.error(`Failed to connect to Dart VM:`, { error });
      // Don't rethrow to allow the application to continue
    }
  }

  /**
   * Send a WebSocket request to the Dart VM
   * @param dartVmPort - The port of the Dart VM, if undefined, the default port will be used
   */
  async sendWebSocketRequest(
    dartVmPort: number | undefined,
    method: string,
    params: Record<string, unknown> = {}
  ): Promise<unknown> {
    try {
      await this.connect(dartVmPort);
      return this.dartVmClient.callMethod(method, params);
    } catch (error) {
      this.logger.error(`WebSocket request failed (${method}):`, { error });
      return null;
    }
  }

  /**
   * Close all WebSocket connections
   */
  async closeAllConnections(): Promise<void> {
    this.dartVmClient.disconnect();
  }

  /**
   * Forwards a request to the Dart VM
   * @param dartVmPort - The port of the Dart VM, if undefined, the default port will be used
   */
  async callDartVm(arg: {
    method: string;
    dartVmPort: number;
    params?: Record<string, unknown>;
    useIsolateIdNumber?: boolean;
  }): Promise<unknown> {
    const { method, dartVmPort, params = {}, useIsolateIdNumber = false } = arg;
    try {
      const flutterIsolateId = await this.getFlutterIsolateId(dartVmPort);
      const isolateId = useIsolateIdNumber
        ? flutterIsolateId.isolateIdNumber
        : flutterIsolateId.isolateId;
      const args = { ...params, isolateId };

      const result = await this.sendWebSocketRequest(dartVmPort, method, args);
      return result;
    } catch (error) {
      this.logger.error(`Error invoking Flutter method ${method}:`, { error });
      throw error;
    }
  }

  /**
   * Call Flutter extension methods via the Dart VM
   */
  async callFlutterExtension(
    method: string,
    params: Record<string, unknown> = {},
    dartVmPort?: number
  ): Promise<FlutterExtensionResponse> {
    try {
      const port = dartVmPort || this.args.dartVMPort;
      const requestId = `req_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

      this.logger.info(
        `[DartVM][${requestId}] Calling Flutter extension method: ${method} with params:`,
        params
      );

      // For non-extension methods, use direct VM service call
      const result = await this.sendWebSocketRequest(port, method, params);
      return result as FlutterExtensionResponse;
    } catch (error) {
      const errorId = `err_${Date.now()}`;
      this.logger.error(
        `[DartVM][${errorId}] Error invoking Flutter method ${method}:`,
        { error }
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
  async getFlutterIsolateId(port: number): Promise<{
    isolateId: string;
    isolateIdNumber: string;
  }> {
    const vmInfo = await this.getVmInfo(port);
    const isolates = vmInfo.isolates;

    // Find Flutter isolate by checking for Flutter extension RPCs
    for (const isolateRef of isolates) {
      const isolate = await this.getIsolate(port, isolateRef.id);

      // Check if this isolate has Flutter extensions
      const extensionRPCs = isolate.extensionRPCs || [];
      if (extensionRPCs.some((ext: string) => ext.startsWith("ext.flutter"))) {
        return {
          isolateId: isolateRef.id,
          isolateIdNumber:
            isolateRef.isolateGroupId?.split("/").pop() ??
            isolateRef.number ??
            "",
          // isolateRef.number ?? isolateRef.id.split("/").pop() ?? "",
        };
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
  async wrapResponse(promise: Promise<unknown>): Promise<RpcToolResponseType> {
    try {
      const result = await promise;
      this.logger.debug(`Wrap response: ${JSON.stringify(result, null, 2)}`);
      const text =
        typeof result === "string" ? result : JSON.stringify(result, null, 2);
      return {
        content: [{ type: "text", text }],
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
  handlePortParam(request: any): number {
    const port = request?.params?.arguments?.port as number | undefined;
    return port || this.args.dartVMPort;
  }
}
