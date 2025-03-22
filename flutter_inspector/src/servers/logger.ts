import { LogLevel } from "../types/types.js";

export class Logger {
  private logLevel: LogLevel;

  constructor(logLevel: LogLevel = "info") {
    this.logLevel = logLevel;
  }

  /**
   * Log a message with the specified level
   */
  log(level: LogLevel, ...args: unknown[]) {
    console.log(`[${level}]`, ...args);
    const levels: LogLevel[] = ["error", "warn", "info", "debug"];
    if (levels.indexOf(level) <= levels.indexOf(this.logLevel)) {
      switch (level) {
        case "error":
          console.error(...args);
          break;
        case "warn":
          console.warn(...args);
          break;
        case "info":
          console.info(...args);
          break;
        case "debug":
          console.debug(...args);
          break;
      }
    }
  }

  error(...args: unknown[]) {
    this.log("error", ...args);
  }

  warn(...args: unknown[]) {
    this.log("warn", ...args);
  }

  info(...args: unknown[]) {
    this.log("info", ...args);
  }

  debug(...args: unknown[]) {
    this.log("debug", ...args);
  }
}
