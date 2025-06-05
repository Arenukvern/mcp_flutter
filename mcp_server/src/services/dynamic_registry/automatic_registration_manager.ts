import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import WebSocket from "ws";
import { Logger } from "../../logger.js";
import { RpcUtilities } from "../../servers/rpc_utilities.js";
import { DynamicToolRegistry } from "./dynamic_tool_registry.js";

/**
 * Event-driven automatic registration manager for Flutter app tools and resources
 * Replaces polling with proper DTD-style event streaming
 */
export class AutomaticRegistrationManager {
  private isListeningForEvents = false;
  private registrationInProgress = false;
  private eventListenerCleanup: (() => void) | null = null;
  private processedIsolates = new Set<string>();
  private streamConnections = new Map<string, WebSocket>();

  constructor(
    private readonly logger: Logger,
    private readonly rpcUtils: RpcUtilities,
    private readonly dynamicRegistry: DynamicToolRegistry,
    private readonly server: Server
  ) {}

  /**
   * Send notification to clients that the tools list has changed
   */
  private async notifyToolsListChanged(): Promise<void> {
    try {
      await this.server.notification({
        method: "notifications/tools/list_changed",
      });
      this.logger.debug(
        "[AutoRegistration] Sent tools/list_changed notification"
      );
    } catch (error) {
      this.logger.warn(
        "[AutoRegistration] Failed to send tools/list_changed notification:",
        { error }
      );
    }
  }

  /**
   * Initialize automatic registration system with event streaming
   */
  async initialize(): Promise<void> {
    this.logger.info(
      "[AutoRegistration] Initializing event-driven registration system"
    );

    await this.startEventStreaming();
    await this.performInitialRegistration();
  }

  /**
   * Perform initial registration when server connects
   */
  private async performInitialRegistration(): Promise<void> {
    this.logger.info(
      "[AutoRegistration] Attempting initial registration on connection"
    );

    try {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      await this.attemptRegistration("initial_connection");
    } catch (error) {
      this.logger.warn(
        "[AutoRegistration] Initial registration failed, will retry on events:",
        { error }
      );
    }
  }

  /**
   * Start event streaming using DTD-style service and editor streams
   */
  private async startEventStreaming(): Promise<void> {
    if (this.isListeningForEvents) {
      return;
    }

    try {
      const dartVmPort = this.rpcUtils.args.dartVMPort;

      // Listen to Service stream for ServiceRegistered events
      await this.subscribeToServiceStream(dartVmPort);

      // Listen to Editor stream for debug session events
      await this.subscribeToEditorStream(dartVmPort);

      this.isListeningForEvents = true;
      this.logger.info("[AutoRegistration] Started DTD-style event streaming");
    } catch (error) {
      this.logger.error("[AutoRegistration] Failed to start event streaming:", {
        error,
      });
    }
  }

  /**
   * Subscribe to Service stream for ServiceRegistered events
   */
  private async subscribeToServiceStream(dartVmPort: number): Promise<void> {
    try {
      // Use DTD streaming pattern
      await this.rpcUtils.sendWebSocketRequest(dartVmPort, "streamListen", {
        streamId: "Service",
      });

      // Set up WebSocket connection for Service events
      await this.setupStreamListener(dartVmPort, "Service", (event) => {
        this.handleServiceEvent(event);
      });

      this.logger.debug("[AutoRegistration] Subscribed to Service stream");
    } catch (error) {
      this.logger.error(
        "[AutoRegistration] Failed to subscribe to Service stream:",
        { error }
      );
    }
  }

  /**
   * Subscribe to Editor stream for debug session events
   */
  private async subscribeToEditorStream(dartVmPort: number): Promise<void> {
    try {
      await this.rpcUtils.sendWebSocketRequest(dartVmPort, "streamListen", {
        streamId: "Editor",
      });

      await this.setupStreamListener(dartVmPort, "Editor", (event) => {
        this.handleEditorEvent(event);
      });

      this.logger.debug("[AutoRegistration] Subscribed to Editor stream");
    } catch (error) {
      this.logger.error(
        "[AutoRegistration] Failed to subscribe to Editor stream:",
        { error }
      );
    }
  }

  /**
   * Set up WebSocket listener for a specific stream
   */
  private async setupStreamListener(
    dartVmPort: number,
    streamId: string,
    handler: (event: any) => void
  ): Promise<void> {
    try {
      const wsUrl = `ws://127.0.0.1:${dartVmPort}/ws`;
      const ws = new WebSocket(wsUrl);

      ws.on("open", () => {
        this.logger.debug(
          `[AutoRegistration] WebSocket connected for ${streamId} stream`
        );
      });

      ws.on("message", (data) => {
        try {
          const message = JSON.parse(data.toString());
          if (
            message.method === "streamNotify" &&
            message.params?.streamId === streamId
          ) {
            handler(message.params.event);
          }
        } catch (error) {
          this.logger.debug(
            `[AutoRegistration] Error parsing ${streamId} event:`,
            { error }
          );
        }
      });

      ws.on("error", (error) => {
        this.logger.warn(
          `[AutoRegistration] WebSocket error for ${streamId}:`,
          { error }
        );
      });

      ws.on("close", () => {
        this.logger.debug(
          `[AutoRegistration] WebSocket closed for ${streamId}`
        );
        this.streamConnections.delete(streamId);
      });

      this.streamConnections.set(streamId, ws);
    } catch (error) {
      this.logger.error(
        `[AutoRegistration] Failed to setup ${streamId} listener:`,
        { error }
      );
    }
  }

  /**
   * Handle Service stream events (ServiceRegistered)
   */
  private async handleServiceEvent(event: any): Promise<void> {
    this.logger.debug("[AutoRegistration] Service event:", event);

    if (event.kind === "ServiceRegistered") {
      const { service, method } = event.data || {};

      // Look for relevant service registrations
      if (
        (service === "Editor" && method === "getDebugSessions") ||
        (service === "MCPToolkit" && method === "registerDynamics")
      ) {
        this.logger.info(
          `[AutoRegistration] ServiceRegistered: ${service}.${method}, attempting registration`
        );
        await this.attemptRegistration("service_registered");
      }
    }
  }

  /**
   * Handle Editor stream events (debugSessionStarted, debugSessionChanged, activeLocationChanged)
   */
  private async handleEditorEvent(event: any): Promise<void> {
    this.logger.debug("[AutoRegistration] Editor event:", event);

    switch (event.kind) {
      case "debugSessionStarted":
        this.logger.info(
          "[AutoRegistration] Debug session started, attempting registration"
        );
        await this.attemptRegistration("debug_session_started");
        break;

      case "debugSessionChanged":
        this.logger.info(
          "[AutoRegistration] Debug session changed, attempting registration"
        );
        await this.attemptRegistration("debug_session_changed");
        break;

      case "activeLocationChanged":
        this.logger.info(
          "[AutoRegistration] Active location changed, attempting registration"
        );
        await this.attemptRegistration("active_location_changed");
        break;

      case "debugSessionStopped":
        // Clean up when debug session stops
        const sessionId = event.data?.debugSessionId;
        if (sessionId) {
          this.processedIsolates.delete(sessionId);
          this.logger.debug(
            `[AutoRegistration] Cleaned up session ${sessionId}`
          );
        }
        break;
    }
  }

  /**
   * Attempt to register tools and resources from Flutter app
   */
  private async attemptRegistration(trigger: string): Promise<void> {
    if (this.registrationInProgress) {
      this.logger.debug(
        "[AutoRegistration] Registration already in progress, skipping"
      );
      return;
    }

    this.registrationInProgress = true;

    try {
      this.logger.info(
        `[AutoRegistration] Attempting registration (trigger: ${trigger})`
      );

      const dartVmPort = this.rpcUtils.args.dartVMPort;

      const result = await this.rpcUtils.callDartVm({
        method: "ext.mcp.toolkit.registerDynamics",
        dartVmPort,
        params: {},
      });

      const {
        tools = [],
        resources = [],
        appId,
      } = result as {
        tools?: any[];
        resources?: any[];
        appId?: string;
      };

      if (!appId) {
        this.logger.warn(
          "[AutoRegistration] Flutter app did not provide appId, skipping registration"
        );
        return;
      }

      // Clear existing registrations for this app to avoid duplicates
      this.dynamicRegistry.clearAppRegistrations(appId);

      const registeredTools: string[] = [];
      const registeredResources: string[] = [];

      // Register all tools
      for (const tool of tools) {
        try {
          this.dynamicRegistry.registerTool(tool, appId, dartVmPort);
          registeredTools.push(tool.name);
        } catch (error) {
          this.logger.warn(
            `[AutoRegistration] Failed to register tool ${tool.name}:`,
            { error }
          );
        }
      }

      // Register all resources
      for (const resource of resources) {
        try {
          this.dynamicRegistry.registerResource(resource, appId, dartVmPort);
          registeredResources.push(resource.uri);
        } catch (error) {
          this.logger.warn(
            `[AutoRegistration] Failed to register resource ${resource.uri}:`,
            { error }
          );
        }
      }

      this.logger.info(
        `[AutoRegistration] Successfully registered ${tools.length} tools and ${resources.length} resources from ${appId} (trigger: ${trigger})`
      );

      // Notify MCP clients that the tools list has changed
      await this.notifyToolsListChanged();
    } catch (error) {
      this.logger.warn(
        `[AutoRegistration] Registration attempt failed (trigger: ${trigger}):`,
        { error }
      );
    } finally {
      this.registrationInProgress = false;
    }
  }

  /**
   * Manually trigger registration (useful for testing or manual refresh)
   */
  async triggerManualRegistration(): Promise<void> {
    await this.attemptRegistration("manual_trigger");
  }

  /**
   * Stop automatic registration and cleanup resources
   */
  async stop(): Promise<void> {
    this.isListeningForEvents = false;

    // Close all WebSocket connections
    for (const [streamId, ws] of this.streamConnections) {
      try {
        ws.close();
        this.logger.debug(
          `[AutoRegistration] Closed ${streamId} stream connection`
        );
      } catch (error) {
        this.logger.debug(
          `[AutoRegistration] Error closing ${streamId} stream:`,
          { error }
        );
      }
    }
    this.streamConnections.clear();

    if (this.eventListenerCleanup) {
      this.eventListenerCleanup();
      this.eventListenerCleanup = null;
    }

    this.logger.info(
      "[AutoRegistration] Stopped event-driven registration system"
    );
  }

  /**
   * Get current status of automatic registration
   */
  getStatus(): {
    isListening: boolean;
    isRegistering: boolean;
    activeStreams: string[];
  } {
    return {
      isListening: this.isListeningForEvents,
      isRegistering: this.registrationInProgress,
      activeStreams: Array.from(this.streamConnections.keys()),
    };
  }
}
