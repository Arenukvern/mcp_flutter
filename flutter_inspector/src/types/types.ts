export interface FlutterPort {
  port: number;
  pid: string;
  command: string;
}

export interface IsolatesResponse {
  isolates: Array<{
    id: string;
    [key: string]: unknown;
  }>;
}

export interface FlutterMethodResponse {
  type?: string;
  result: unknown;
}

export interface WebSocketRequest {
  jsonrpc: "2.0";
  id: string;
  method: string;
  params?: Record<string, unknown>;
}

export interface WebSocketResponse {
  jsonrpc: "2.0";
  id: string;
  result?: unknown;
  error?: {
    code: number;
    message: string;
    data?: unknown;
  };
}

export type LogLevel = "error" | "warn" | "info" | "debug";

export interface IsolateInfo {
  id: string;
  name?: string;
  number?: string;
  isSystemIsolate?: boolean;
  isolateGroupId?: string;
  extensionRPCs?: string[];
}

export interface VMInfo {
  isolates: IsolateInfo[];
  version?: string;
  pid?: number;
  // Add other VM info fields as needed
}

export interface IsolateResponse extends IsolateInfo {
  extensionRPCs?: string[];
  // Add other isolate response fields as needed
}
