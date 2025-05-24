/**
 * @fileoverview Implementation of the Model Context Protocol (MCP) Logger.
 * Provides structured logging capabilities with security features and MCP server integration.
 * Follows RFC 5424 for log levels and implements the MCP logging specification.
 * @see https://spec.modelcontextprotocol.io/specification/2025-03-26/server/utilities/logging/
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import util from "util";

/**
 * Standard log levels as defined in RFC 5424.
 * Ordered from highest severity (emergency) to lowest (debug).
 */
export enum LogLevel {
  /** Error conditions | Operation failures */
  Error = "error",
  /** Debugging information | Function entry/exit points */
  Debug = "debug",
  /** General informational messages | Operation progress updates */
  Info = "info",
  /** Normal but significant events | Configuration changes */
  Notice = "notice",
  /** Warning conditions | Deprecated feature usage */
  Warning = "warning",
  /** Critical conditions | System component failures */
  Critical = "critical",
  /** Action must be taken immediately | Data corruption detected */
  Alert = "alert",
  /** System is unusable | Complete system failure */
  Emergency = "emergency",
}

/**
 * Structured log data format.
 * Ensures consistent log message structure across the application.
 */
export interface LogData {
  /** The main log message */
  message: string;
  /** Optional contextual data for the log entry */
  context?: Record<string, unknown>;
  /** Unix timestamp of when the log was created */
  timestamp: number;
  /** Name of the server/service that generated the log */
  serverName: string;
  /** Severity level of the log entry */
  level: LogLevel;
}

/**
 * JSON-RPC error codes as defined in the MCP specification.
 */
export enum LoggerError {
  /** Invalid parameters provided to the logger */
  InvalidParams = -32602,
  /** Internal logger error */
  InternalError = -32603,
}

/**
 * Patterns used to identify and redact sensitive information in log messages.
 * @const {RegExp[]}
 */
const SENSITIVE_PATTERNS = [
  /pass/i,
  /password/i,
  /token/i,
  /key/i,
  /secret/i,
  /credential/i,
  /auth/i,
];

/**
 * MCP-compliant logger implementation with security features and rate limiting.
 * Provides structured logging with sensitive data filtering and fallback to console output.
 */
export class Logger {
  /** Queue of pending log messages */
  private messageQueue: Array<LogData> = [];
  /** Flag to prevent concurrent queue processing */
  private isProcessingQueue = false;
  /** Timestamp of the last processed message for rate limiting */
  private lastMessageTime = 0;
  /** Minimum time between log messages in milliseconds */
  private readonly RATE_LIMIT_MS = 100;
  /** Maximum number of messages to keep in the queue */
  private readonly MAX_QUEUE_SIZE = 1000;

  /**
   * Creates a new Logger instance.
   * @param serverName - Identifier for the logging source
   * @param level - Minimum log level to process (default: "info")
   * @param server - Optional MCP server instance for remote logging
   */
  constructor(
    private readonly serverName: string,
    private level: LogLevel = LogLevel.Info,
    private server?: Server
  ) {}

  /**
   * Updates the MCP server instance for this logger.
   * @param server - New MCP server instance
   */
  public async setServer(server: Server): Promise<void> {
    this.server = server;
  }

  /**
   * Validates and normalizes log data.
   * @param data - Partial log data to validate
   * @returns Complete and validated log data
   * @throws {LoggerError} If message is missing or invalid
   */
  private validateLogData(data: Partial<LogData>): LogData {
    if (!data.message || typeof data.message !== "string") {
      throw { code: LoggerError.InvalidParams, message: "Invalid log message" };
    }

    return {
      message: data.message,
      context: data.context || {},
      timestamp: data.timestamp || Date.now(),
      serverName: this.serverName,
      level: data.level || LogLevel.Info,
    };
  }

  /**
   * Filters sensitive information from log data.
   * Recursively processes objects to mask sensitive values.
   * @param data - Log data to filter
   * @returns Filtered log data with sensitive information redacted
   */
  private filterSensitiveData(data: LogData): LogData {
    const maskValue = (value: string): string => {
      for (const pattern of SENSITIVE_PATTERNS) {
        if (pattern.test(value)) {
          return "***REDACTED***";
        }
      }
      return value;
    };

    const filterObject = (
      obj: Record<string, unknown>
    ): Record<string, unknown> => {
      const filtered: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(obj)) {
        if (typeof value === "string") {
          filtered[key] = maskValue(value);
        } else if (typeof value === "object" && value !== null) {
          filtered[key] = filterObject(value as Record<string, unknown>);
        } else {
          filtered[key] = value;
        }
      }
      return filtered;
    };

    return {
      ...data,
      message: maskValue(data.message),
      context: data.context ? filterObject(data.context) : {},
    };
  }

  /**
   * Formats arguments into a string representation.
   * @param args - Array of arguments to format
   * @returns Formatted string
   */
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

  /**
   * Processes the message queue with rate limiting.
   * Ensures messages are sent in order and within rate limits.
   */
  private async processQueue() {
    if (this.isProcessingQueue) return;
    this.isProcessingQueue = true;

    try {
      while (this.messageQueue.length > 0) {
        const now = Date.now();
        if (now - this.lastMessageTime < this.RATE_LIMIT_MS) {
          await new Promise((resolve) =>
            setTimeout(resolve, this.RATE_LIMIT_MS)
          );
          continue;
        }

        const logData = this.messageQueue.shift();
        if (!logData) continue;

        this.lastMessageTime = now;
        await this.sendToServer(logData);
      }
    } finally {
      this.isProcessingQueue = false;
    }
  }

  /**
   * Sends a log message to the MCP server or falls back to console.
   * @param logData - Log data to send
   */
  private async sendToServer(logData: LogData): Promise<void> {
    try {
      if (this.server) {
        const filteredData = this.filterSensitiveData(logData);
        await this.server.sendLoggingMessage({
          level: filteredData.level,
          data: {
            message: filteredData.message,
            context: filteredData.context,
            timestamp: filteredData.timestamp,
          },
          logger: this.serverName,
        });
      } else {
        this.logToConsole(logData);
      }
    } catch (error) {
      this.logToConsole({
        ...logData,
        level: LogLevel.Error,
        message: `Failed to send log message: ${error}`,
      });
    }
  }

  /**
   * Outputs a log message to the appropriate console method.
   * @param logData - Log data to output
   */
  private logToConsole(logData: LogData): void {
    const prefix = `[${logData.level.toUpperCase()}]`;
    const message = `${prefix} ${logData.message}`;

    switch (logData.level) {
      case "error":
      case "critical":
      case "emergency":
        console.error(message);
        break;
      case "warning":
      case "alert":
        console.warn(message);
        break;
      case "info":
      case "notice":
        console.info(message);
        break;
      default:
        console.log(message);
    }
  }

  /**
   * Checks if a message should be logged based on current log level.
   * @param messageLevel - Level of the message to check
   * @returns Whether the message should be logged
   */
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

  /**
   * Queues a message for processing.
   * @param level - Log level of the message
   * @param message - Message content
   * @param context - Optional context data
   */
  private queueMessage(
    level: LogLevel,
    message: string,
    context?: Record<string, unknown>
  ) {
    if (this.messageQueue.length >= this.MAX_QUEUE_SIZE) {
      this.messageQueue.shift();
    }

    const logData = this.validateLogData({
      message,
      context,
      level,
      timestamp: Date.now(),
      serverName: this.serverName,
    });

    this.messageQueue.push(logData);
    this.processQueue().catch(() => {});
  }

  /**
   * Logs an error message.
   * @param message - Error description
   * @param context - Optional error context
   */
  error(message: string, context?: Record<string, unknown>): void {
    if (this.shouldLog(LogLevel.Error)) {
      this.queueMessage(LogLevel.Error, message, context);
    }
  }

  /**
   * Logs a critical system condition.
   * @param message - Critical condition description
   * @param context - Optional context data
   */
  critical(message: string, context?: Record<string, unknown>): void {
    if (this.shouldLog(LogLevel.Critical)) {
      this.queueMessage(LogLevel.Critical, message, context);
    }
  }

  /**
   * Logs an alert that requires immediate attention.
   * @param message - Alert description
   * @param context - Optional alert context
   */
  alert(message: string, context?: Record<string, unknown>): void {
    if (this.shouldLog(LogLevel.Alert)) {
      this.queueMessage(LogLevel.Alert, message, context);
    }
  }

  /**
   * Logs an emergency condition that renders the system unusable.
   * @param message - Emergency condition description
   * @param context - Optional emergency context
   */
  emergency(message: string, context?: Record<string, unknown>): void {
    if (this.shouldLog(LogLevel.Emergency)) {
      this.queueMessage(LogLevel.Emergency, message, context);
    }
  }

  /**
   * Logs a warning message.
   * @param message - Warning description
   * @param context - Optional warning context
   */
  warn(message: string, context?: Record<string, unknown>): void {
    if (this.shouldLog(LogLevel.Warning)) {
      this.queueMessage(LogLevel.Warning, message, context);
    }
  }

  /**
   * Logs a notice message for normal but significant events.
   * @param message - Notice description
   * @param context - Optional notice context
   */
  notice(message: string, context?: Record<string, unknown>): void {
    if (this.shouldLog(LogLevel.Notice)) {
      this.queueMessage(LogLevel.Notice, message, context);
    }
  }

  /**
   * Logs an informational message.
   * @param message - Information to log
   * @param context - Optional information context
   */
  info(message: string, context?: Record<string, unknown>): void {
    if (this.shouldLog(LogLevel.Info)) {
      this.queueMessage(LogLevel.Info, message, context);
    }
  }

  /**
   * Logs a debug message with detailed information.
   * @param message - Debug information
   * @param context - Optional debug context
   */
  debug(message: string, context?: Record<string, unknown>): void {
    if (this.shouldLog(LogLevel.Debug)) {
      this.queueMessage(LogLevel.Debug, message, context);
    }
  }

  /**
   * Temporarily changes the log level for a specific operation.
   * @param tempLevel - Temporary log level to use
   * @param fn - Async function to execute with temporary log level
   * @returns Promise that resolves with the function result
   * @template T - Type of the function result
   */
  public async withLogLevel<T>(
    tempLevel: LogLevel,
    fn: () => Promise<T>
  ): Promise<T> {
    const originalLevel = this.level;
    this.level = tempLevel;
    try {
      return await fn();
    } finally {
      this.level = originalLevel;
    }
  }

  public async setLogLevel(level: LogLevel): Promise<void> {
    if (!this.shouldLog(level)) {
      throw {
        code: LoggerError.InvalidParams,
        message: "Invalid log level",
      };
    }
    this.level = level;
  }
}
