import { Resource, ResourceTemplate } from "@modelcontextprotocol/sdk/types.js";
import { RpcUtilities } from "../servers/rpc_utilities.js";
// TODO: maybe convert to yaml file, if it will grow
// TODO: properly write description for each resource - it should be clear for client what will be returned
export const createTreeResources = (rpcUtils: RpcUtilities): Resource[] => {
  const resources = [
    // TODO:
    // {
    //   uri: "visual://localhost/tree/root",
    //   name: "Widget Tree Root",
    //   description: "Get the root widget of the Flutter application",
    //   mimeType: "application/json",
    // },
    // TODO:
    // {
    //   uri: "visual://localhost/app/info",
    //   name: "App Info",
    //   description: "Get app information (size of screen, pixel ratio etc.)",
    //   mimeType: "application/json",
    // },
    {
      uri: "visual://localhost/app/errors/latest",
      name: "Latest Application Error",
      description: "Get one latest application error. ",
      mimeType: "application/json",
    },
  ];

  if (!rpcUtils.args.areResourcesSupported) {
    return [];
  }
  if (rpcUtils.args.areImagesSupported) {
    resources.push({
      uri: "visual://localhost/view/screenshots",
      name: "Screenshots",
      description:
        "Get screenshots of all views in the application. Returns a base64 encoded images.",
      mimeType: "image/png",
    });
  }
  return resources;
};

export const TREE_RESOURCES_TEMPLATES: ResourceTemplate[] = [
  // {
  //   uriTemplate: "visual://localhost/tree/node/{node_id}",
  //   name: "Widget Node",
  //   description: "Get details of a specific widget node",
  //   mimeType: "application/json",
  // },
  {
    uriTemplate: "visual://localhost/app/errors/{count}",
    name: "Get latest application errors",
    description:
      "Get certain number of latest application errors. Ask no more then 4.",
    mimeType: "application/json",
  },
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
];
