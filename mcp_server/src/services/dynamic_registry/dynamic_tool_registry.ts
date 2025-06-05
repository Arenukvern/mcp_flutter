import { Resource, Tool } from "@modelcontextprotocol/sdk/types.js";
import { Logger } from "../../logger.js";

export interface DynamicToolEntry {
  tool: Tool;
  sourceApp: string;
  dartVmPort: number;
  registeredAt: Date;
}

export interface DynamicResourceEntry {
  resource: Resource;
  sourceApp: string;
  dartVmPort: number;
  registeredAt: Date;
}

/**
 * Dynamic registry for tools and resources registered by Flutter applications
 * Manages runtime registration and cleanup when apps disconnect
 */
export class DynamicToolRegistry {
  private tools = new Map<string, DynamicToolEntry>();
  private resources = new Map<string, DynamicResourceEntry>();
  private appConnections = new Map<string, number>(); // appId -> dartVmPort

  constructor(private logger: Logger) {}

  /**
   * Register a new tool from a Flutter application
   */
  registerTool(tool: Tool, sourceApp: string, dartVmPort: number): void {
    const entry: DynamicToolEntry = {
      tool,
      sourceApp,
      dartVmPort,
      registeredAt: new Date(),
    };

    this.tools.set(tool.name, entry);
    this.appConnections.set(sourceApp, dartVmPort);

    this.logger.info(
      `[DynamicRegistry] Registered tool: ${tool.name} from ${sourceApp}:${dartVmPort}`
    );
  }

  /**
   * Register a new resource from a Flutter application
   */
  registerResource(
    resource: Resource,
    sourceApp: string,
    dartVmPort: number
  ): void {
    const entry: DynamicResourceEntry = {
      resource,
      sourceApp,
      dartVmPort,
      registeredAt: new Date(),
    };

    this.resources.set(resource.uri, entry);
    this.appConnections.set(sourceApp, dartVmPort);

    this.logger.info(
      `[DynamicRegistry] Registered resource: ${resource.uri} from ${sourceApp}:${dartVmPort}`
    );
  }

  /**
   * Remove all tools and resources from a specific app
   */
  unregisterApp(sourceApp: string): void {
    // Remove tools
    for (const [toolName, entry] of this.tools.entries()) {
      if (entry.sourceApp === sourceApp) {
        this.tools.delete(toolName);
        this.logger.info(
          `[DynamicRegistry] Unregistered tool: ${toolName} from ${sourceApp}`
        );
      }
    }

    // Remove resources
    for (const [resourceUri, entry] of this.resources.entries()) {
      if (entry.sourceApp === sourceApp) {
        this.resources.delete(resourceUri);
        this.logger.info(
          `[DynamicRegistry] Unregistered resource: ${resourceUri} from ${sourceApp}`
        );
      }
    }

    this.appConnections.delete(sourceApp);
  }

  /**
   * Clear all registrations for a specific app (alias for unregisterApp)
   * Used by automatic registration to avoid duplicates
   */
  clearAppRegistrations(sourceApp: string): void {
    this.unregisterApp(sourceApp);
  }

  /**
   * Handle port change - treat as new app registration
   */
  handlePortChange(sourceApp: string, newPort: number): void {
    const oldPort = this.appConnections.get(sourceApp);
    if (oldPort && oldPort !== newPort) {
      this.logger.info(
        `[DynamicRegistry] Port changed for ${sourceApp}: ${oldPort} -> ${newPort}`
      );
      this.unregisterApp(sourceApp);
    }
  }

  /**
   * Get all dynamically registered tools
   */
  getDynamicTools(): Tool[] {
    return Array.from(this.tools.values()).map((entry) => entry.tool);
  }

  /**
   * Get all dynamically registered resources
   */
  getDynamicResources(): Resource[] {
    return Array.from(this.resources.values()).map((entry) => entry.resource);
  }

  /**
   * Get tool entry by name
   */
  getToolEntry(name: string): DynamicToolEntry | undefined {
    return this.tools.get(name);
  }

  /**
   * Get resource entry by URI
   */
  getResourceEntry(uri: string): DynamicResourceEntry | undefined {
    return this.resources.get(uri);
  }

  /**
   * Check if a tool is dynamically registered
   */
  isDynamicTool(name: string): boolean {
    return this.tools.has(name);
  }

  /**
   * Check if a resource is dynamically registered
   */
  isDynamicResource(uri: string): boolean {
    return this.resources.has(uri);
  }

  /**
   * Get registry statistics
   */
  getStats(): {
    toolCount: number;
    resourceCount: number;
    appCount: number;
    apps: Array<{
      name: string;
      port: number;
      toolCount: number;
      resourceCount: number;
    }>;
  } {
    const appStats = new Map<
      string,
      { port: number; toolCount: number; resourceCount: number }
    >();

    // Count tools per app
    for (const entry of this.tools.values()) {
      if (!appStats.has(entry.sourceApp)) {
        appStats.set(entry.sourceApp, {
          port: entry.dartVmPort,
          toolCount: 0,
          resourceCount: 0,
        });
      }
      appStats.get(entry.sourceApp)!.toolCount++;
    }

    // Count resources per app
    for (const entry of this.resources.values()) {
      if (!appStats.has(entry.sourceApp)) {
        appStats.set(entry.sourceApp, {
          port: entry.dartVmPort,
          toolCount: 0,
          resourceCount: 0,
        });
      }
      appStats.get(entry.sourceApp)!.resourceCount++;
    }

    return {
      toolCount: this.tools.size,
      resourceCount: this.resources.size,
      appCount: this.appConnections.size,
      apps: Array.from(appStats.entries()).map(([name, stats]) => ({
        name,
        port: stats.port,
        toolCount: stats.toolCount,
        resourceCount: stats.resourceCount,
      })),
    };
  }
}
