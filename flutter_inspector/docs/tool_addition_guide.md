# Adding New Tools to Flutter Inspector

## Tool Definition Process

Adding a new tool requires updating two files:

1. `server_tools_flutter.yaml`: Define the tool interface
2. `server_tools_handler.yaml`: Implement the RPC handler

After editing, run `npm run generate-rpc-handlers` to update generated files.

## Tool Naming Rules

- Use snake_case for tool names
- Follow the prefixing pattern:
  - `debug_*`: For debugging visualization tools
  - `inspector_*`: For Flutter inspector-related tools
  - `dart_io_*`: For Dart I/O related functionality
  - `flutter_core_*`: For core Flutter framework functionality

## Tool Structure in `server_tools_flutter.yaml`

```yaml
tools:
  - name: tool_name # Required: snake_case
    description: "Tool purpose" # Required: Clear description with "RPC:" prefix
    inputSchema: # Required: JSONSchema for tool inputs
      type: object
      properties:
        param1: # Parameter definition
          type: type # number, string, boolean, etc.
          description: "Details" # Parameter description
        port: # Optional port parameter
          type: number
          description: "Optional port number"
      required: [] # List of required parameters
```

## Handler Structure in `server_tools_handler.yaml`

```yaml
handlers:
  - name: tool_name # Must match name in server_tools_flutter.yaml
    description: "Purpose" # Brief description of handler functionality
    rpcMethod: "ext.flutter.xyz" # Actual Flutter/Dart RPC method
    needsDebugVerification: true # Whether to verify debug mode
    needsDartServiceExtensionProxy: true/false # Use Dart proxy?
    responseWrapper: true # Wrap response in standard format
    parameters: # Parameter mapping rules
      param1: "" # Direct parameter (params?.param1)
      param2: "arg.propName" # Nested in arg object
```

## Property Rules

1. **Tool Definition Properties:**

   - `name`: Must be unique, snake_case
   - `description`: Start with "RPC:" for RPC methods
   - `inputSchema`: Valid JSONSchema object
   - `properties`: Define expected parameters
   - `required`: Array of required parameter names

2. **Handler Properties:**
   - `name`: Must match the tool definition name
   - `rpcMethod`: Valid Flutter/Dart method name
   - `needsDartServiceExtensionProxy`:
     - Set to `true` for all `inspector_*` tools
     - Set to `false` for other tools
   - `parameters`: Maps user parameters to RPC parameters
     - `""`: Direct mapping (no transformation)
     - `"arg.x"`: Nested in `arg` object

## Important Conventions

1. **Inspector Tools:**

   - All `inspector_*` tools must have `needsDartServiceExtensionProxy: true`
   - Use `arg.` prefix for parameters that need to be nested

2. **Parameter Handling:**

   - Always include `port` parameter for all tools
   - For toggle parameters, use `enabled` as the parameter name
   - Use descriptive names for IDs (e.g., `objectId`, `selectionId`)

3. **Response Formatting:**
   - Keep `responseWrapper: true` for consistent formatting
   - Ensure all responses can be serialized to JSON
