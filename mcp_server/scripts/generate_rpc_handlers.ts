// scripts/generate_rpc_handlers.ts
import fs from "fs";
import yaml from "js-yaml";
import path from "path";
import { fileURLToPath } from "url";

// Get the directory name in ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function generateRpcHandlers() {
  const dartHandlerYamlFilePath = path.resolve(
    __dirname,
    "ext.dart.handler.yaml"
  );
  const flutterHandlerYamlFilePath = path.resolve(
    __dirname,
    "ext.flutter.handler.yaml"
  );

  const generatedFilePath = path.resolve(
    __dirname,
    "..",
    "src",
    "servers",
    "flutter_rpc_handlers.generated.ts"
  );
  const handlerMapFilePath = path.resolve(
    __dirname,
    "..",
    "src",
    "servers",
    "create_rpc_handler_map.generated.ts"
  );

  try {
    const dartHandlerYamlContent = fs.readFileSync(
      dartHandlerYamlFilePath,
      "utf8"
    );
    const flutterHandlerYamlContent = fs.readFileSync(
      flutterHandlerYamlFilePath,
      "utf8"
    );
    const dartHandlerConfig = yaml.load(dartHandlerYamlContent) as {
      handlers: any[];
    };
    const flutterHandlerConfig = yaml.load(flutterHandlerYamlContent) as {
      handlers: any[];
    };
    const handlers = [
      ...dartHandlerConfig.handlers,
      ...flutterHandlerConfig.handlers,
    ];

    let generatedCode = `
import { RpcUtilities } from "./rpc_utilities.js";

/**
 * Generated class containing handlers for Flutter RPC tools.
 *
 * This class is generated from server_tools_handler.yaml.
 * Do not edit this file directly.
 */
export class FlutterRpcHandlers {
  private rpcUtils: RpcUtilities;

  constructor(rpcUtils: RpcUtilities) {
    this.rpcUtils = rpcUtils;
  }
`;

    for (const handler of handlers) {
      const methodName = `handle${handler.name
        .split("_")
        .map((part: string) => part.charAt(0).toUpperCase() + part.slice(1))
        .join("")}`;
      const description = handler.description.replace(/\n/g, "\n   * "); // Format description for JSDoc
      const rpcMethod = handler.rpcMethod;
      const needsDebugVerification = handler.needsDebugVerification === true;
      const needsDartServiceExtensionProxy =
        handler.needsDartServiceExtensionProxy === true;
      const responseWrapper = handler.responseWrapper !== false; // Default to true if not explicitly false
      const parameters = handler.parameters || {};

      let rpcParamsObject: string = "{}";

      if (Object.keys(parameters).length > 0) {
        let hasArg = false;
        let argProperties: string[] = [];

        rpcParamsObject = "{ ";
        for (const [paramName, paramMapping] of Object.entries(parameters) as [
          string,
          string
        ][]) {
          if (paramMapping === "") {
            rpcParamsObject += `${paramName}: params?.${paramName}, `;
          } else if (paramMapping === "port") {
            rpcParamsObject += `${paramName}: port, `;
          } else if (paramMapping.startsWith("arg.")) {
            const rpcParamName = paramMapping.substring(4); // Remove "arg." prefix
            hasArg = true;
            argProperties.push(`${rpcParamName}: params?.${paramName}`);
          } else if (paramMapping === "arg") {
            rpcParamsObject += `arg: params?.${paramName}, `;
          }
        }

        // Add arg object if there are arg properties
        if (hasArg) {
          rpcParamsObject += `arg: { ${argProperties.join(", ")} }, `;
        }

        rpcParamsObject = rpcParamsObject.slice(0, -2) + " }"; // Remove trailing comma and space
      }

      // Determine which method to use based on whether it needs the Dart proxy
      const invokeMethod = needsDartServiceExtensionProxy
        ? `this.rpcUtils.callFlutterExtension("${rpcMethod}", port,${rpcParamsObject.trim()})`
        : `this.rpcUtils.callDartVm("${rpcMethod}", port, ${rpcParamsObject.trim()})`;

      generatedCode += `
  /**
   * ${description}
   */
  async ${methodName}(port: number, params?: any): Promise<unknown> {
    ${
      needsDebugVerification
        ? "await this.rpcUtils.verifyFlutterDebugMode(port);"
        : ""
    }
    const result = await ${invokeMethod};
    ${
      responseWrapper
        ? "return this.rpcUtils.wrapResponse(Promise.resolve(result));"
        : "return result;"
    }
  }
  `;
    }

    generatedCode += `
}
`;

    // Generate the createRpcHandlerMap function
    let mapCode = `
// GENERATED CODE - DO NOT MODIFY BY HAND
// This file is generated from server_tools_handler.yaml
// Run "npm run generate-rpc-handlers" to update

import { FlutterRpcHandlers } from "./flutter_rpc_handlers.generated.js";

/**
 * Generated createRpcHandlerMap method for the FlutterInspectorServer class.
 * 
 * @param rpcHandlers The FlutterRpcHandlers instance
 * @param handlePortParam A function to extract the port parameter from a request
 * @returns A mapping of tool names to handler functions
 */
export function createRpcHandlerMap(
  rpcHandlers: FlutterRpcHandlers,
  handlePortParam: (request: any) => number
): Record<string, any> {
  return {
`;

    for (const handler of handlers) {
      const handlerName = handler.name;
      const methodName = `handle${handlerName
        .split("_")
        .map((part: string) => part.charAt(0).toUpperCase() + part.slice(1))
        .join("")}`;

      const hasParams = Object.keys(handler.parameters || {}).length > 0;

      mapCode += `    "${handlerName}": (request: any) => {
      const port = handlePortParam(request);
      ${hasParams ? "const params = request.params.arguments;" : ""}
      return rpcHandlers.${methodName}(port${hasParams ? ", params" : ""});
    },
`;
    }

    mapCode += `  };
}`;

    fs.writeFileSync(generatedFilePath, generatedCode.trim() + "\n");
    fs.writeFileSync(handlerMapFilePath, mapCode.trim() + "\n");

    console.log(`Generated FlutterRpcHandlers class at: ${generatedFilePath}`);
    console.log(
      `Generated createRpcHandlerMap function at: ${handlerMapFilePath}`
    );
  } catch (error) {
    console.error("Error generating RPC handlers:", error);
  }
}

generateRpcHandlers();
