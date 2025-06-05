import { type Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequest,
  CallToolResult,
  ErrorCode,
  ListResourcesRequestSchema,
  ListResourceTemplatesRequestSchema,
  McpError,
  ReadResourceRequestSchema,
  ResourceContents,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { RpcUtilities } from "../servers/rpc_utilities.js";
import { DynamicToolRegistry } from "../services/dynamic_registry/dynamic_tool_registry.js";
import { FlutterRpcHandlers } from "../tools/flutter_rpc_handlers.generated.js";
import { CustomRpcHandlerMap } from "../tools/index.js";
import {
  createTreeResources,
  TREE_RESOURCES_TEMPLATES,
} from "./widget_tree_resources.js";

const _RPC_PREFIX = "ext.mcp.toolkit.";

/**
 * Tool configurations for resource-related operations
 * All methods route through Dart VM backend
 */
const ToolNames = {
  getAppErrors: {
    toolName: "get_app_errors",
    rpcMethod: `${_RPC_PREFIX}app_errors`,
  },
  getViewDetails: {
    toolName: "get_view_details",
    rpcMethod: `${_RPC_PREFIX}view_details`,
  },
  viewScreenshots: {
    toolName: "view_screenshots",
    rpcMethod: `${_RPC_PREFIX}view_screenshots`,
  },
} as const;

type ScreenshotResult = {
  images: string[];
};

type AppErrorsResponse = {
  message: string;
  errors: unknown[];
};

type ViewDetailsResponse = {
  message: string;
  details: unknown[];
};

type ResourceType =
  | "root"
  | "node"
  | "parent"
  | "children"
  | "screenshot"
  | "app_errors"
  | "view_details"
  | "view_widget_tree"
  | "is_widget_tree_ready"
  | "unknown";

/**
 * Handles all resource-related operations for the Flutter Inspector
 * All operations route through Dart VM backend for consistency
 */
export class ResourcesHandlers {
  public setHandlers(
    server: Server,
    rpcUtils: RpcUtilities,
    rpcToolHandlers: FlutterRpcHandlers,
    dynamicRegistry?: DynamicToolRegistry
  ): void {
    // List available resources when clients request them - dynamically fetch resources on each request
    server.setRequestHandler(ListResourcesRequestSchema, async () => {
      const staticResources = createTreeResources(rpcUtils);
      const dynamicResources = dynamicRegistry?.getDynamicResources() || [];

      return {
        resources: [...staticResources, ...dynamicResources],
      };
    });

    // List available resource templates when clients request them
    server.setRequestHandler(ListResourceTemplatesRequestSchema, async () => {
      return { resourceTemplates: [...TREE_RESOURCES_TEMPLATES] };
    });

    // Return resource content when clients request it
    server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      return this.#handleRead(request.params.uri, rpcUtils, rpcToolHandlers);
    });
  }

  /**
   * Get the flutter application errors list via Dart VM
   * @param count - The count of errors to get
   * @param rpcUtils - The RPC utilities
   * @returns The errors list
   */
  async #getErrorsList(
    count: number | undefined,
    rpcUtils: RpcUtilities
  ): Promise<{
    errorsListJson: AppErrorsResponse;
    errorsList: unknown[];
  }> {
    const dartVmPort = rpcUtils.args.dartVMPort;
    const appErrorsResult = await rpcUtils.callDartVm({
      method: ToolNames.getAppErrors.rpcMethod,
      dartVmPort,
      params: {
        count: count ?? 4,
      },
    });

    const errorsListJson = appErrorsResult as AppErrorsResponse;
    const errorsList = errorsListJson?.errors ?? [];

    return {
      errorsListJson,
      errorsList,
    };
  }

  /**
   * Get view details via Dart VM
   * @param rpcUtils - The RPC utilities
   * @returns View details response
   */
  async #getViewDetails(rpcUtils: RpcUtilities): Promise<ViewDetailsResponse> {
    const dartVmPort = rpcUtils.args.dartVMPort;
    const viewDetailsResult = await rpcUtils.callDartVm({
      method: ToolNames.getViewDetails.rpcMethod,
      dartVmPort,
    });
    const viewDetailsResultJson = viewDetailsResult as ViewDetailsResponse;

    return {
      message: viewDetailsResultJson.message,
      details: viewDetailsResultJson.details,
    };
  }

  /**
   * Handle resource read requests
   * All operations route through Dart VM backend
   */
  async #handleRead(
    uri: string,
    rpcUtils: RpcUtilities,
    rpcToolHandlers: FlutterRpcHandlers
  ): Promise<ResourceContents> {
    const parsedUri = this.#parseUri(uri);

    try {
      switch (parsedUri.type) {
        case "root":
          const rootResult = await rpcToolHandlers.handleToolRequest(
            "inspector_get_root_widget",
            {}
          );
          return {
            uri: uri,
            contents: rootResult.content.map((content) => ({
              json: JSON.parse(content.text)?.data?.result,
              uri: uri,
              mimeType: "application/json",
            })),
          };

        case "node":
          if (!parsedUri.nodeId) {
            throw new McpError(ErrorCode.InvalidParams, "Node ID is required");
          }
          // Route through Dart VM (via callFlutterExtension which now uses Dart VM)
          const nodeResult = await rpcUtils.callFlutterExtension(
            "ext.flutter.inspector.getProperties",
            {
              objectId: parsedUri.nodeId,
            }
          );
          return {
            uri: uri,
            contents: [
              {
                uri: uri,
                json: nodeResult,
                mimeType: "application/json",
              },
            ],
          };

        case "parent":
          if (!parsedUri.nodeId) {
            throw new McpError(ErrorCode.InvalidParams, "Node ID is required");
          }
          // Route through Dart VM (via callFlutterExtension which now uses Dart VM)
          const parentResult = await rpcUtils.callFlutterExtension(
            "ext.flutter.inspector.getParentChain",
            {
              objectId: parsedUri.nodeId,
            }
          );
          return {
            uri: uri,
            contents: [
              {
                uri: uri,
                json: parentResult,
                mimeType: "application/json",
              },
            ],
          };

        case "children":
          if (!parsedUri.nodeId) {
            throw new McpError(ErrorCode.InvalidParams, "Node ID is required");
          }
          // Route through Dart VM (via callFlutterExtension which now uses Dart VM)
          const childrenResult = await rpcUtils.callFlutterExtension(
            "ext.flutter.inspector.getChildrenDetailsSubtree",
            {
              objectId: parsedUri.nodeId,
            }
          );
          return {
            uri: uri,
            contents: [
              {
                uri: uri,
                json: childrenResult,
                mimeType: "application/json",
              },
            ],
          };

        case "app_errors":
          try {
            const { errorsListJson, errorsList } = await this.#getErrorsList(
              parsedUri.count,
              rpcUtils
            );
            return {
              uri: uri,
              contents:
                errorsList.length == 0
                  ? [
                      {
                        uri: uri,
                        text: errorsListJson.message,
                        mimeType: "text/plain",
                      },
                    ]
                  : [
                      {
                        uri: uri,
                        text: errorsListJson.message,
                        json: errorsList,
                        mimeType: "application/json",
                      },
                    ],
            };
          } catch (error) {
            throw new McpError(
              ErrorCode.InternalError,
              `Failed to get app errors: ${error}`
            );
          }

        case "view_details":
          const viewDetailsResult = await this.#getViewDetails(rpcUtils);
          return {
            uri: uri,
            contents: [
              {
                uri: uri,
                text: viewDetailsResult.message,
                json: viewDetailsResult.details,
                mimeType: "application/json",
              },
            ],
          };

        case "view_widget_tree":
          // Route through Dart VM (via callFlutterExtension which now uses Dart VM)
          const viewResult = await rpcUtils.callFlutterExtension(
            "ext.flutter.inspector.getRootWidgetSummaryTreeWithPreviews",
            {
              includeProperties: true,
              subtreeDepth: -1,
            }
          );
          return {
            uri: uri,
            contents: [
              {
                uri: uri,
                json: viewResult,
                mimeType: "application/json",
              },
            ],
          };

        case "is_widget_tree_ready":
          // Route through Dart VM (via callFlutterExtension which now uses Dart VM)
          const infoResult = await rpcUtils.callFlutterExtension(
            "ext.flutter.inspector.isWidgetTreeReady",
            {}
          );
          return {
            uri: uri,
            contents: [
              {
                uri: uri,
                json: infoResult,
                mimeType: "application/json",
              },
            ],
          };

        case "screenshot":
          // Route through Dart VM
          const screenshotResult = (await rpcUtils.callDartVm({
            method: ToolNames.viewScreenshots.rpcMethod,
            dartVmPort: rpcUtils.args.dartVMPort,
            params: {
              compress: true,
            },
          })) as ScreenshotResult | undefined;
          return {
            uri: uri,
            contents:
              screenshotResult?.images.map((image) => ({
                uri: uri,
                blob: image,
                mimeType: "image/png",
              })) ?? [],
          };
      }
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to handle resource request for ${uri}`
      );
    } catch (error) {
      if (error instanceof McpError) {
        throw error;
      }
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to handle resource request: ${error}`
      );
    }
  }

  /**
   * Parse the URI to get the resource type and parameters.
   * @param uri - The URI to parse.
   * @returns The resource type and parameters.
   */
  #parseUri(uri: string): {
    type: ResourceType;
    nodeId?: string;
    count?: number;
  } {
    try {
      const parsedUri = new URL(uri);

      if (parsedUri.protocol !== "visual:") {
        return { type: "unknown" };
      }

      const host = parsedUri.host;
      const pathParts = parsedUri.pathname.split("/").filter(Boolean);

      if (pathParts.length < 2) {
        return { type: "unknown" };
      }

      const [category, action, ...rest] = pathParts;

      switch (category) {
        case "tree":
          if (action === "root") {
            return { type: "root" };
          } else if (["node", "parent", "children"].includes(action)) {
            return {
              type: action as ResourceType,
              nodeId: rest[0],
            };
          }
          break;

        case "app":
          if (action === "errors") {
            let count: number;
            if (rest.includes("latest")) {
              count = 1;
            } else {
              const countParam = rest[rest.length - 1];
              count =
                countParam && !isNaN(parseInt(countParam))
                  ? parseInt(countParam)
                  : 10; // Default to 10 if not specified or invalid
            }
            return {
              type: "app_errors",
              count,
            };
          }
          break;

        case "view":
          if (action === "is_widget_tree_ready") {
            return { type: "is_widget_tree_ready" };
          } else if (action === "screenshots") {
            return {
              type: "screenshot",
            };
          } else if (action === "details") {
            return { type: "view_details" };
          }
          return { type: "unknown" };
      }

      return { type: "unknown" };
    } catch (e) {
      return { type: "unknown" };
    }
  }

  /**
   * Get the tools for the resources if resources are not supported.
   * @param rpcUtils - The RPC utilities.
   * @returns The tools.
   */
  getTools(
    rpcUtils: RpcUtilities,
    rpcToolHandlers: FlutterRpcHandlers
  ): CustomRpcHandlerMap {
    if (rpcUtils.args.areResourcesSupported) {
      return {};
    }
    const tools = <CustomRpcHandlerMap>{
      [ToolNames.getViewDetails.toolName]: async (
        request: CallToolRequest
      ): Promise<CallToolResult> => {
        const viewDetailsResult = await this.#getViewDetails(rpcUtils);
        return {
          content: [
            {
              type: "text",
              text: viewDetailsResult.message,
            },
            {
              type: "text",
              text: JSON.stringify(viewDetailsResult.details, null, 2),
            },
          ],
        };
      },
      [ToolNames.getAppErrors.toolName]: async (
        request: CallToolRequest
      ): Promise<CallToolResult> => {
        const count = request.params.arguments?.count;
        const { errorsListJson, errorsList } = await this.#getErrorsList(
          count as number,
          rpcUtils
        );
        return {
          content: [
            {
              type: "text",
              text:
                errorsListJson.message ||
                "MCP Toolkit is not active. Make sure devtools in browser is not disconnected and MCP Toolkit is running.",
            },
            {
              type: "text",
              text: JSON.stringify(errorsList, null, 2),
            },
          ],
        };
      },
    };
    if (rpcUtils.args.areImagesSupported) {
      tools[ToolNames.viewScreenshots.toolName] = async (request) => {
        const compress = request.params.arguments?.compress;
        const screenshotResult = (await rpcUtils.callDartVm({
          method: ToolNames.viewScreenshots.rpcMethod,
          dartVmPort: rpcUtils.args.dartVMPort,
          params: {
            compress: compress ?? true,
          },
        })) as ScreenshotResult;
        const uri = request.params.uri;
        return {
          content: screenshotResult.images.map((image) => ({
            type: "image",
            data: image,
            mimeType: "image/png",
          })),
        };
      };
    }
    return tools;
  }

  /**
   * Get the tool schemes for the resources if resources are not supported.
   * @param rpcUtils - The RPC utilities.
   * @returns The tool schemes.
   */
  getToolSchemes(rpcUtils: RpcUtilities): Tool[] {
    const screenshot = <Tool>{
      name: ToolNames.viewScreenshots.toolName,
      description: "Get the screenshot of the app",
      inputSchema: {
        type: "object",
        properties: {},
        required: [],
      },
    };
    if (rpcUtils.args.areResourcesSupported) {
      return [];
    }
    const tools = <Tool[]>[
      {
        name: ToolNames.getAppErrors.toolName,
        description: "Get the errors of the app",
        inputSchema: {
          type: "object",
          properties: {
            count: {
              type: "number",
              description: "The count of errors to get. Ask no more then 4.",
            },
          },
          required: [],
        },
      },
      {
        name: ToolNames.getViewDetails.toolName,
        description: "Get the details of the views in the app.",
        inputSchema: {
          type: "object",
          properties: {},
          required: [],
        },
      },
    ];
    if (rpcUtils.args.areImagesSupported) {
      tools.push(screenshot);
    }
    return tools.map((tool) => ({
      ...tool,
      name: toSnakeCase(tool.name),
    }));
  }
}

/**
 * Converts a camelCase or PascalCase string to snake_case.
 * @param str - The input string.
 * @returns The snake_case version of the string.
 */
function toSnakeCase(str: string): string {
  return str
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/([A-Z])([A-Z][a-z])/g, "$1_$2")
    .toLowerCase();
}
