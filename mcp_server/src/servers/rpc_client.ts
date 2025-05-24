import WebSocket from "ws";
import { Logger } from "../logger.js";

export class RpcClient {
  constructor(public logger: Logger) {}
  private ws: WebSocket | null = null;
  private pendingRequests = new Map<
    string,
    { resolve: Function; reject: Function; method: string }
  >();
  private messageId = 0;
  private connectionInProgress: Promise<void> | null = null;

  /**
   * Generate a unique ID for requests
   */
  private generateId(): string {
    return `${Date.now()}_${this.messageId++}`;
  }

  /**
   * Connect to the RPC server with timeout protection
   */
  async connect(
    host: string,
    port: number,
    path: string,
    timeoutMs = 100000
  ): Promise<void> {
    this.logger?.debug(`Connecting to RPC server at ${host}:${port}${path}`);
    // If already connecting, return the existing promise
    if (this.connectionInProgress) {
      this.logger?.debug(
        `Already connecting to RPC server. Ignoring new request.`
      );
      return this.connectionInProgress;
    }

    const readyState = this.ws?.readyState;
    this.logger?.debug(`readyState: ${readyState}`);

    // Only return early if the WebSocket is in OPEN state
    if (readyState === WebSocket.OPEN) {
      this.logger?.debug(`Already connected to RPC server`);
      return Promise.resolve();
    }

    // If WebSocket exists but is not open, close and recreate it
    if (this.ws) {
      this.logger?.debug(`Closing existing WebSocket connection`);
      this.ws.close();
      this.ws = null;
    }

    // Create new WebSocket connection with timeout
    this.connectionInProgress = new Promise<void>((resolve, reject) => {
      const wsUrl = `ws://${host}:${port}${path}`;
      this.ws = new WebSocket(wsUrl);
      this.logger?.debug(`Connecting to RPC server at ${wsUrl}`);

      // Create a timeout to prevent hanging
      const timeoutId = setTimeout(() => {
        const error = new Error(
          `Connection to ${wsUrl} timed out after ${timeoutMs}ms`
        );
        if (this.ws) {
          this.ws.close();
          this.ws = null;
        }
        reject(error);
      }, timeoutMs);

      this.ws.onopen = () => {
        this.logger?.debug(`Connected to RPC server at ${wsUrl}`);
        clearTimeout(timeoutId);
        resolve();
      };

      this.ws.onerror = (error: any) => {
        this.logger?.error(`WebSocket error:`, error);
        clearTimeout(timeoutId);

        if (this.ws) {
          this.ws.close();
          this.ws = null;
        }

        reject(error);
      };

      this.ws.onclose = () => {
        this.logger?.debug(`Disconnected from RPC server`);
        clearTimeout(timeoutId);
        this.ws = null;
      };

      this.ws.onmessage = (event) => {
        try {
          const response = JSON.parse(event.data.toString());

          if (response.id) {
            const request = this.pendingRequests.get(response.id);
            if (request) {
              if (response.error) {
                request.reject(new Error(response.error.message));
              } else {
                request.resolve(response.result);
              }
              this.pendingRequests.delete(response.id);
            }
          }
        } catch (error) {
          this.logger.error("Error parsing WebSocket message:", { error });
        }
      };
    }).finally(() => {
      this.connectionInProgress = null;
    });

    return this.connectionInProgress;
  }

  /**
   * Call a method on the RPC server
   */
  async callMethod(
    method: string,
    params: Record<string, unknown> = {}
  ): Promise<unknown> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error(`Not connected to RPC server ${this.ws?.readyState}`);
    }

    const id = this.generateId();

    const request = {
      jsonrpc: "2.0",
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      // Add a timeout to prevent indefinite hanging
      const timeoutId = setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error(`Request ${method} timed out after 30000ms`));
        }
      }, 30000);

      this.pendingRequests.set(id, {
        resolve: (result: any) => {
          clearTimeout(timeoutId);
          resolve(result);
        },
        reject: (error: Error) => {
          clearTimeout(timeoutId);
          reject(error);
        },
        method,
      });

      this.ws!.send(JSON.stringify(request));
    });
  }

  /**
   * Disconnect from the RPC server
   */
  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}
