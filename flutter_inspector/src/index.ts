#!/usr/bin/env node
import * as dotenv from "dotenv";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import {
  defaultMCPServerPort,
  FlutterInspectorServer,
} from "./servers/flutter_inspector_server.js";
import { LogLevel } from "./types/types.js";

// Load environment variables
dotenv.config();
export interface CommandLineConfig {
  port: number;
  stdio: boolean;
  logLevel: LogLevel;
  host: string;
}

export class CommandLineArgs {
  private constructor(private readonly config: CommandLineConfig) {}

  get port() {
    return this.config.port;
  }
  get stdio() {
    return this.config.stdio;
  }
  get logLevel() {
    return this.config.logLevel as LogLevel;
  }
  get host() {
    return this.config.host;
  }

  static fromCommandLine(): CommandLineArgs {
    const argv = yargs(hideBin(process.argv))
      .options({
        port: {
          alias: "p",
          description: "Port to run the server on",
          type: "number",
          default: parseInt(process.env.PORT || `${defaultMCPServerPort}`, 10),
        },
        stdio: {
          description: "Run in stdio mode instead of HTTP mode",
          type: "boolean",
          default: true,
        },
        "log-level": {
          description: "Logging level",
          choices: ["error", "warn", "info", "debug"] as const,
          default: process.env.LOG_LEVEL || "error",
        },
        host: {
          description: "Host to run the server on",
          type: "string",
          default: process.env.HOST || "localhost",
        },
      })
      .help()
      .parseSync();

    return new CommandLineArgs({
      port: argv.port,
      stdio: argv.stdio,
      logLevel: argv["log-level"] as LogLevel,
      host: argv.host,
    });
  }
}

const args = CommandLineArgs.fromCommandLine();

const server = new FlutterInspectorServer(args);
server.run().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
