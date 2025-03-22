import WebSocket from "ws";

export class RpcClient {
  private ws: WebSocket | null = null;
  private pendingRequests = new Map<
    string,
    { resolve: Function; reject: Function; method: string }
  >();
  private messageId = 0;

  /**
   * Generate a unique ID for requests
   */
  private generateId(): string {
    return `${Date.now()}_${this.messageId++}`;
  }

  /**
   * Connect to the Flutter RPC server
   */
  async connect(host: string, port: number, path: string): Promise<void> {
    const readyState = this.ws?.readyState;
    console.log(`readyState: ${readyState}`);

    // Only return early if the WebSocket is in OPEN state
    if (readyState === WebSocket.OPEN) {
      console.log(`Already connected to Flutter RPC server`);
      return Promise.resolve();
    }

    // If WebSocket exists but is not open, close and recreate it
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }

    // Create new WebSocket connection
    return new Promise((resolve, reject) => {
      const wsUrl = `ws://${host}:${port}${path}`;
      this.ws = new WebSocket(wsUrl);
      console.log(`Connecting to Flutter RPC server at ${wsUrl}`);

      this.ws.onopen = () => {
        console.log(`Connected to Flutter RPC server at ${wsUrl}`);
        resolve();
      };

      this.ws.onerror = (error) => {
        console.error(`WebSocket error:`, error);
        reject(error);
      };

      this.ws.onclose = () => {
        console.log(`Disconnected from Flutter RPC server`);
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
          console.error("Error parsing WebSocket message:", error);
        }
      };
    });
  }

  /**
   * Call a method on the Flutter RPC server
   */
  async callMethod(
    method: string,
    params: Record<string, unknown> = {}
  ): Promise<unknown> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error(
        `Not connected to Flutter RPC server ${this.ws?.readyState}`
      );
    }

    const id = this.generateId();

    const request = {
      jsonrpc: "2.0",
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(id, { resolve, reject, method });
      this.ws!.send(JSON.stringify(request));
    });
  }

  /**
   * Disconnect from the Flutter RPC server
   */
  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}
