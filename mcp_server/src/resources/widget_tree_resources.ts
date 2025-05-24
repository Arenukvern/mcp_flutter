import { Resource, ResourceTemplate } from "@modelcontextprotocol/sdk/types.js";
import { RpcUtilities } from "../servers/rpc_utilities.js";

/**
 * Creates widget tree resources for the Flutter Inspector
 * All resources are designed to work with Dart VM backend
 * TODO: Consider converting to YAML file if this grows significantly
 * TODO: Enhance descriptions to be clearer for MCP clients
 */
export const createTreeResources = (rpcUtils: RpcUtilities): Resource[] => {
  const resources = [
    // TODO: Enable when widget tree navigation is fully implemented
    // {
    //   uri: "visual://localhost/tree/root",
    //   name: "Widget Tree Root",
    //   description: "Get the root widget of the Flutter application",
    //   mimeType: "application/json",
    // },

    {
      uri: "visual://localhost/app/errors/latest",
      name: "Latest Application Error",
      description: "Get the most recent application error from Dart VM",
      mimeType: "application/json",
    },
  ];

  // Return empty if resources are not supported (will use tools instead)
  if (!rpcUtils.args.areResourcesSupported) {
    return [];
  }

  // View resources - all via Dart VM backend
  if (rpcUtils.args.areImagesSupported) {
    resources.push({
      uri: "visual://localhost/view/screenshots",
      name: "Screenshots",
      description:
        "Get screenshots of all views in the application. Returns base64 encoded images.",
      mimeType: "image/png",
    });
  }

  resources.push({
    uri: "visual://localhost/view/details",
    name: "View Details",
    description:
      "Get details for all views in the application. View equals one window on desktop, or one running instance on mobile.",
    mimeType: "application/json",
  });

  return resources;
};

/**
 * Resource templates for dynamic resource creation
 * All templates work with Dart VM backend
 */
export const TREE_RESOURCES_TEMPLATES: ResourceTemplate[] = [
  // TODO: Enable when widget tree navigation is fully implemented for Dart VM
  // {
  //   uriTemplate: "visual://localhost/tree/node/{node_id}",
  //   name: "Widget Node",
  //   description: "Get details of a specific widget node",
  //   mimeType: "application/json",
  // },
  // {
  //   uriTemplate: "visual://localhost/tree/parent/{node_id}",
  //   name: "Widget Node Parent",
  //   description: "Get parent of a specific widget node",
  //   mimeType: "application/json",
  // },
  // {
  //   uriTemplate: "visual://localhost/tree/children/{node_id}",
  //   name: "Widget Node Children",
  //   description: "Get children of a specific widget node",
  //   mimeType: "application/json",
  // },

  {
    uriTemplate: "visual://localhost/app/errors/{count}",
    name: "Application Errors",
    description:
      "Get a specified number of latest application errors. Limit to 4 or fewer for performance.",
    mimeType: "application/json",
  },
];
