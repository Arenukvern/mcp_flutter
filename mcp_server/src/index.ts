#!/usr/bin/env node
import * as dotenv from "dotenv";
import { LogLevel } from "flutter_mcp_forwarding_server";
import yargs from "yargs";
import { FlutterInspectorServer } from "./servers/flutter_inspector_server.js";

export const defaultEnvConfig = {
  dartVMPort: 8181,
  dartVMHost: "localhost",
  mcpServerPort: 3535,
  mcpServerHost: "localhost",
  forwardingServerPort: 8143,
  forwardingServerHost: "localhost",
};

// Load environment variables
dotenv.config();
export interface CommandLineConfig {
  port: number;
  host: string;
  stdio: boolean;
  logLevel: LogLevel;
  dartVMPort: number;
  dartVMHost: string;
  forwardingServerPort: number;
  forwardingServerHost: string;
}

export class CommandLineArgs {
  private constructor(public readonly config: CommandLineConfig) {}

  static fromCommandLine(): CommandLineArgs {
    const argv = yargs(process.argv)
      .options({
        port: {
          alias: "p",
          description: "Port to run the server on",
          type: "number",
          default: parseInt(
            process.env.PORT || `${defaultEnvConfig.mcpServerPort}`,
            10
          ),
        },
        host: {
          alias: "h",
          description: "Host to run the mcp server on",
          type: "string",
          default:
            process.env.MCP_SERVER_HOST || defaultEnvConfig.mcpServerHost,
        },
        dartVMPort: {
          alias: "dart-vm-port",
          description: "Port to run the dart vm on",
          type: "number",
          default: parseInt(
            process.env.DART_VM_PORT || `${defaultEnvConfig.dartVMPort}`,
            10
          ),
        },
        dartVMHost: {
          alias: "dart-vm-host",
          description: "Host to run the dart vm on",
          type: "string",
          default: process.env.DART_VM_HOST || defaultEnvConfig.dartVMHost,
        },
        forwardingServerPort: {
          alias: "forwarding-server-port",
          description: "Port to run the forwarding server on",
          type: "number",
          default: parseInt(
            process.env.FORWARDING_SERVER_PORT ||
              `${defaultEnvConfig.forwardingServerPort}`,
            10
          ),
        },
        forwardingServerHost: {
          alias: "forwarding-server-host",
          description: "Host to run the forwarding server on",
          type: "string",
          default:
            process.env.FORWARDING_SERVER_HOST ||
            defaultEnvConfig.forwardingServerHost,
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
      })
      .help()
      .parseSync();

    return new CommandLineArgs({
      stdio: argv.stdio,
      logLevel: argv["log-level"] as LogLevel,
      dartVMPort: argv.dartVMPort,
      dartVMHost: argv.dartVMHost,
      forwardingServerPort: argv.forwardingServerPort,
      forwardingServerHost: argv.forwardingServerHost,
      port: argv.port,
      host: argv.host,
    });
  }
}

const args = CommandLineArgs.fromCommandLine().config;

const server = new FlutterInspectorServer(args);
server.run().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
