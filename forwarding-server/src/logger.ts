import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import util from "util";

export type LogLevel =
  | "error"
  | "debug"
  | "info"
  | "notice"
  | "warning"
  | "critical"
  | "alert"
  | "emergency";

export class Logger {
  private messageQueue: Array<{ level: LogLevel; message: string }> = [];
  private isProcessingQueue = false;
  private lastMessageTime = 0;
  private readonly RATE_LIMIT_MS = 100; // Minimum time between messages
  private readonly MAX_QUEUE_SIZE = 1000; // Maximum number of messages in queue

  constructor(
    private readonly serverName: string,
    private level: LogLevel = "info",
    private readonly server?: Server
  ) {}

  private shouldLog(messageLevel: LogLevel): boolean {
    const levels: Record<LogLevel, number> = {
      emergency: 0,
      critical: 1,
      error: 2,
      alert: 3,
      warning: 4,
      notice: 5,
      info: 6,
      debug: 7,
    };

    return levels[messageLevel] <= levels[this.level];
  }

  private formatArgs(args: any[]): string {
    return args
      .map((arg) => {
        if (typeof arg === "string") {
          return arg;
        }
        return util.inspect(arg, {
          depth: 5,
          colors: false,
          maxArrayLength: 20,
          compact: true,
        });
      })
      .join(" ");
  }

  private async processQueue() {
    if (this.isProcessingQueue) return;
    this.isProcessingQueue = true;

    while (this.messageQueue.length > 0) {
      const now = Date.now();
      if (now - this.lastMessageTime < this.RATE_LIMIT_MS) {
        await new Promise((resolve) => setTimeout(resolve, this.RATE_LIMIT_MS));
        continue;
      }

      const messageContainer = this.messageQueue.shift();
      if (!messageContainer) continue;

      this.lastMessageTime = now;
      const level = messageContainer.level;
      const message = messageContainer.message;

      // Send to MCP server if available
      if (this.server) {
        try {
          await this.server.sendLoggingMessage({
            level: level,
            data: message,
            logger: this.serverName,
          });
        } catch (error) {
          // Fallback to stderr on error
          console.error(`[${level.toUpperCase()}] ${message}`);
        }
      } else {
        // Log to stderr based on level
        if (
          level === "error" ||
          level === "critical" ||
          level === "emergency"
        ) {
          console.error(`[${level.toUpperCase()}] ${message}`);
        } else if (level === "warning" || level === "alert") {
          console.warn(`[${level.toUpperCase()}] ${message}`);
        } else if (level === "info" || level === "notice") {
          console.info(`[${level.toUpperCase()}] ${message}`);
        } else {
          console.log(`[${level.toUpperCase()}] ${message}`);
        }
      }
    }

    this.isProcessingQueue = false;
  }

  private queueMessage(level: LogLevel, message: string) {
    if (this.messageQueue.length >= this.MAX_QUEUE_SIZE) {
      // Drop oldest message if queue is full
      this.messageQueue.shift();
    }
    this.messageQueue.push({ level, message });
    this.processQueue().catch(() => {}); // Start processing queue
  }

  error(...args: any[]): void {
    if (this.shouldLog("error")) {
      this.queueMessage("error", this.formatArgs(args));
    }
  }

  critical(...args: any[]): void {
    if (this.shouldLog("critical")) {
      this.queueMessage("critical", this.formatArgs(args));
    }
  }

  alert(...args: any[]): void {
    if (this.shouldLog("alert")) {
      this.queueMessage("alert", this.formatArgs(args));
    }
  }

  emergency(...args: any[]): void {
    if (this.shouldLog("emergency")) {
      this.queueMessage("emergency", this.formatArgs(args));
    }
  }

  warn(...args: any[]): void {
    if (this.shouldLog("warning")) {
      this.queueMessage("warning", this.formatArgs(args));
    }
  }

  notice(...args: any[]): void {
    if (this.shouldLog("notice")) {
      this.queueMessage("notice", this.formatArgs(args));
    }
  }

  info(...args: any[]): void {
    if (this.shouldLog("info")) {
      this.queueMessage("info", this.formatArgs(args));
    }
  }

  debug(...args: any[]): void {
    if (this.shouldLog("debug")) {
      this.queueMessage("debug", this.formatArgs(args));
    }
  }

  // Helper method to temporarily increase log level for a specific operation
  async withLogLevel<T>(tempLevel: LogLevel, fn: () => Promise<T>): Promise<T> {
    const originalLevel = this.level;
    this.level = tempLevel;
    try {
      return await fn();
    } finally {
      this.level = originalLevel;
    }
  }
}
