// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_inspector_mcp_server/src/server.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// MCP tools for managing dynamic registry
/// These tools allow clients to interact with dynamically registered tools and resources
@immutable
final class DynamicRegistryTools {
  const DynamicRegistryTools({required this.registry, required this.server});

  final DynamicRegistry registry;
  final MCPToolkitServer server;

  // Reusable text constants for setup instructions
  static const _setupWorkflowText =
      'To create new tools/resources: 1) Generate MCPCallEntry.tool() or MCPCallEntry.resource() with handler and definition, '
      '2) Add to Flutter app (in main.dart, widget tree, or state management like provider/riverpod) using addMcpTool(), '
      '3) Use listClientToolsAndResources to verify the tool is registered, '
      '4) Hot reload the app to activate. '
      '5) Use runClientTool to execute the tool. ';

  static const _exactMatchingText =
      'Names/URIs must match exactly what appears in listClientToolsAndResources. ';

  static const _schemaComplianceText =
      "Arguments should conform to the tool's inputSchema requirements. ";
  static const _listClientToolsAndResourcesDescription =
      'Discover all dynamically registered tools and resources from the connected Flutter application. '
      'Use this as your first step to understand what debugging and inspection capabilities are available. '
      'Returns tool definitions with names, descriptions, and input schemas, plus available resources with URIs. '
      "Essential for planning your debugging workflow and understanding the app's current MCP toolkit setup. "
      '\n\n$_setupWorkflowText'
      'See server instructions for detailed examples of creating custom MCPCallEntry definitions.';

  /// Tool to list all client tools and resources
  static final listClientToolsAndResources = Tool(
    name: 'listClientToolsAndResources',
    description: _listClientToolsAndResourcesDescription,
    inputSchema: ObjectSchema(properties: {}),
  );

  /// Tool to run a client tool
  static final runClientTool = Tool(
    name: 'runClientTool',
    description:
        'Execute a specific dynamically registered tool from the Flutter application. '
        'Use this to run debugging tools, inspect app state, take screenshots, analyze errors, or execute custom tools. '
        '$_exactMatchingText'
        '$_schemaComplianceText'
        'This is your primary way to interact with Flutter app functionality beyond static MCP server tools. '
        '\n\nFor custom tools: $_setupWorkflowText'
        'Example: Create MCPCallEntry.tool() with handler: (params) => MCPCallResult(...), then register and hot reload.',
    inputSchema: ObjectSchema(
      required: ['toolName'],
      properties: {
        'toolName': Schema.string(
          description:
              'Exact name of the tool to execute (from listClientToolsAndResources)',
        ),
        'arguments': Schema.object(
          description:
              'Arguments to pass to the tool, matching its inputSchema requirements',
          additionalProperties: true,
        ),
      },
    ),
  );

  /// Tool to read a client resource
  static final runClientResource = Tool(
    name: 'runClientResource',
    description:
        'Read content from a dynamically registered resource in the Flutter application. '
        'Resources provide structured data like app state, view details, or configuration information. '
        "Use this to access read-only information that doesn't require tool execution. "
        '$_exactMatchingText'
        'Typically used for getting current app state snapshots or accessing structured data. '
        '\n\nFor custom resources: $_setupWorkflowText'
        'Example: Create MCPCallEntry.resource() with handler: (uri) => MCPCallResult(...), then register and hot reload.',
    inputSchema: ObjectSchema(
      required: ['resourceUri'],
      properties: {
        'resourceUri': Schema.string(
          description:
              'Exact URI of the resource to read (from listClientToolsAndResources)',
        ),
      },
    ),
  );

  /// Tool to get registry statistics
  static final getRegistryStats = Tool(
    name: 'getRegistryStats',
    description: 'Get statistics about the dynamic registry',
    inputSchema: ObjectSchema(
      properties: {
        'includeAppDetails': Schema.bool(
          description: 'Include detailed app information (default: true)',
        ),
      },
    ),
  );

  /// Tool to get pub package documentation (README)
  static final getPubDoc = Tool(
    name: 'get_pub_doc',
    description:
        'Get the README documentation for a Dart/Flutter package. By default, parses pubspec.yaml from the app root to resolve hosted, git, or path dependencies. You can override with manual arguments. Priority: pubspec > local_path > git_path > pub.dev > pub cache.',
    inputSchema: ObjectSchema(
      properties: {
        'package': Schema.string(
          description: 'The package name to fetch documentation for',
        ),
        'fvm_sdk_path': Schema.string(
          description: 'Optional: The FVM SDK path to use for pub cache lookup',
        ),
        'git_path': Schema.string(
          description:
              'Optional: The local path to the checked-out git dependency',
        ),
        'local_path': Schema.string(
          description: 'Optional: The local path to the dependency',
        ),
        'pubspec_path': Schema.string(
          description:
              'Optional: Path to pubspec.yaml (defaults to ./pubspec.yaml)',
        ),
      },
    ),
  );

  /// Tool to get Dart member documentation (stub)
  static final getDartMemberDoc = Tool(
    name: 'get_dart_member_doc',
    description:
        'Get the documentation for a Dart member (class, function, etc.). Currently a stub.',
    inputSchema: ObjectSchema(
      properties: {
        'member': Schema.string(
          description:
              'The Dart member name (class, function, etc.) to fetch documentation for',
        ),
      },
    ),
  );

  /// Get all management tools
  Map<Tool, FutureOr<CallToolResult> Function(CallToolRequest)> get allTools =>
      {
        listClientToolsAndResources: _handleListClientToolsAndResources,
        runClientTool: _handleRunClientTool,
        runClientResource: _handleRunClientResource,
        if (kDebugMode) getRegistryStats: _handleGetRegistryStats,
        getPubDoc: _handleGetPubDoc,
        getDartMemberDoc: _handleGetDartMemberDoc,
      };

  FutureOr<CallToolResult> _handleListClientToolsAndResources(
    final CallToolRequest request,
  ) async {
    await server.discoveryService?.registerToolsAndResources();

    final toolEntries = registry.getToolEntries();
    final resourceEntries = registry.getResourceEntries();

    final result = <String, dynamic>{
      'tools': toolEntries.map((final entry) => entry.tool).toList(),
      'resources':
          resourceEntries.map((final entry) => entry.resource).toList(),
      'summary': {
        'totalTools': toolEntries.length,
        'totalResources': resourceEntries.length,
      },
    };

    if (resourceEntries.isEmpty) {
      result['resources'] = [];
    }

    return CallToolResult(
      content: [
        TextContent(text: _setupWorkflowText),
        TextContent(text: jsonEncode(result)),
      ],
      isError: false,
    );
  }

  FutureOr<CallToolResult> _handleRunClientTool(
    final CallToolRequest request,
  ) async {
    final arguments = request.arguments;
    final toolName = jsonDecodeString(arguments?['toolName']);
    if (toolName.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required parameter: toolName')],
        isError: true,
      );
    }

    final toolArguments = jsonDecodeMapAs<String, Object?>(
      arguments?['arguments'],
    );

    // Forward to the dynamic registry
    final result = await registry.forwardToolCall(toolName, toolArguments);

    if (result == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Tool not found: $toolName. '
                'Use listClientToolsAndResources to see available tools.',
          ),
        ],
        isError: true,
      );
    }

    return result;
  }

  FutureOr<CallToolResult> _handleRunClientResource(
    final CallToolRequest request,
  ) async {
    final arguments = request.arguments;
    final resourceUri = jsonDecodeString(arguments?['resourceUri']);
    if (resourceUri.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required parameter: resourceUri')],
        isError: true,
      );
    }

    // Forward to the dynamic registry
    final content = await registry.forwardResourceRead(resourceUri);

    if (content == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Resource not found: $resourceUri. '
                'Use listClientToolsAndResources to see available resources.',
          ),
        ],
        isError: true,
      );
    }

    return CallToolResult(
      content: content.contents.map((final c) => c.toContent()).toList(),
      isError: false,
    );
  }

  FutureOr<CallToolResult> _handleGetRegistryStats(
    final CallToolRequest request,
  ) {
    final arguments = request.arguments;
    final includeAppDetails = jsonDecodeBool(arguments?['includeAppDetails']);
    final info = registry.appInfo;
    if (info == null) {
      return CallToolResult(
        content: [TextContent(text: 'No app info available')],
        isError: true,
      );
    }

    final result = <String, dynamic>{
      'toolCount': info.toolCount,
      'resourceCount': info.resourceCount,
      if (includeAppDetails) ...info,
    };

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result))],
      isError: false,
    );
  }

  FutureOr<CallToolResult> _handleGetPubDoc(
    final CallToolRequest request,
  ) async {
    final args = request.arguments;
    final package = args?['package']?.toString();
    final fvmSdkPath = args?['fvm_sdk_path']?.toString();
    final gitPathArg = args?['git_path']?.toString();
    final localPathArg = args?['local_path']?.toString();
    final pubspecPath = args?['pubspec_path']?.toString() ?? 'pubspec.yaml';
    String? resolvedLocalPath;
    String? resolvedGitPath;
    String? resolvedPackage;
    // 1. Try to parse pubspec.yaml if package is provided and no manual path overrides
    if (package != null &&
        package.isNotEmpty &&
        (gitPathArg == null || gitPathArg.isEmpty) &&
        (localPathArg == null || localPathArg.isEmpty)) {
      try {
        final pubspecFile = File(pubspecPath);
        if (pubspecFile.existsSync()) {
          final pubspecContent = pubspecFile.readAsStringSync();
          final pubspec = loadYaml(pubspecContent) as YamlMap;
          final deps = pubspec['dependencies'] as YamlMap?;
          final dep = deps != null ? deps[package] : null;
          if (dep is String) {
            // Hosted dependency
            resolvedPackage = package;
          } else if (dep is YamlMap) {
            if (dep['git'] != null) {
              // Git dependency
              // Try to resolve .pub-cache/git/<package> or .pub-cache/git/<repo>
              // But for now, fallback to pubspec.yaml location + .pub-cache/git
              // (User should provide git_path for best results)
              // Optionally, try to guess from .pub-cache/git
              // We'll fallback to pub.dev if not found
            } else if (dep['path'] != null) {
              // Path dependency
              final relPath = dep['path'].toString();
              final pubspecDir = p.dirname(pubspecFile.absolute.path);
              resolvedLocalPath = p.normalize(p.join(pubspecDir, relPath));
            }
          }
        }
      } catch (_) {}
    }
    // Use resolved paths from pubspec.yaml if found
    final localPath = resolvedLocalPath ?? localPathArg;
    final gitPath = resolvedGitPath ?? gitPathArg;
    final effectivePackage = resolvedPackage ?? package;
    if ((effectivePackage == null || effectivePackage.isEmpty) &&
        (gitPath == null || gitPath.isEmpty) &&
        (localPath == null || localPath.isEmpty)) {
      return CallToolResult(
        content: [
          TextContent(text: 'No package, git_path, or local_path provided.'),
        ],
        isError: true,
      );
    }
    // Priority: local_path > git_path > pub.dev > pub cache
    // 1. Local path
    if (localPath != null && localPath.isNotEmpty) {
      final readmeFile = File(p.join(localPath, 'README.md'));
      if (readmeFile.existsSync()) {
        final content = readmeFile.readAsStringSync();
        return CallToolResult(
          content: [
            TextContent(text: content),
            TextContent(text: '{"source":"local_path"}'),
          ],
          isError: false,
        );
      }
    }
    // 2. Git path
    if (gitPath != null && gitPath.isNotEmpty) {
      final readmeFile = File(p.join(gitPath, 'README.md'));
      if (readmeFile.existsSync()) {
        final content = readmeFile.readAsStringSync();
        return CallToolResult(
          content: [
            TextContent(text: content),
            TextContent(text: '{"source":"git"}'),
          ],
          isError: false,
        );
      }
    }
    // 3. pub.dev
    if (effectivePackage != null && effectivePackage.isNotEmpty) {
      final pubDevUrl =
          'https://pub.dev/packages/$effectivePackage/versions/latest/README.md';
      try {
        final response = await http.get(Uri.parse(pubDevUrl));
        if (response.statusCode == 200) {
          return CallToolResult(
            content: [
              TextContent(text: response.body),
              TextContent(text: '{"source":"pub.dev"}'),
            ],
            isError: false,
          );
        }
      } catch (_) {}
      // 4. Fallback: try local pub cache
      String pubCache;
      if (fvmSdkPath != null && fvmSdkPath.isNotEmpty) {
        pubCache = p.join(
          fvmSdkPath,
          '.pub-cache',
          'hosted',
          'pub.dev',
          effectivePackage,
        );
      } else {
        final home =
            Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            '';
        pubCache = p.join(
          home,
          '.pub-cache',
          'hosted',
          'pub.dev',
          effectivePackage,
        );
      }
      String? readmeContent;
      try {
        final dir = Directory(pubCache);
        if (dir.existsSync()) {
          final files = dir.listSync(recursive: true).whereType<File>();
          final readmeFiles = files.where(
            (final f) => p.basename(f.path).toLowerCase() == 'readme.md',
          );
          if (readmeFiles.isNotEmpty) {
            final readmeFile = readmeFiles.first;
            readmeContent = readmeFile.readAsStringSync();
          }
        }
      } catch (_) {}
      if (readmeContent != null && readmeContent.isNotEmpty) {
        return CallToolResult(
          content: [
            TextContent(text: readmeContent),
            TextContent(text: '{"source":"local"}'),
          ],
          isError: false,
        );
      }
    }
    return CallToolResult(
      content: [
        TextContent(text: ''),
        TextContent(text: '{"source":"not_found"}'),
      ],
      isError: false,
    );
  }

  FutureOr<CallToolResult> _handleGetDartMemberDoc(
    final CallToolRequest request,
  ) async {
    final args = request.arguments;
    final member = args?['member']?.toString();
    if (member == null || member.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'No member name provided.')],
        isError: true,
      );
    }
    // Stub: Real implementation would query Dart Analysis Server
    return CallToolResult(
      content: [
        TextContent(
          text:
              'Documentation lookup for "$member" is not yet implemented. (Stub)',
        ),
      ],
      isError: false,
    );
  }
}

extension on ResourceContents {
  Content toContent() {
    final mimeType = this.mimeType;
    if (mimeType == null ||
        mimeType.startsWith('text/') ||
        mimeType.startsWith('application/')) {
      final textContent = this as TextResourceContents;
      return TextContent(text: textContent.text);
    } else if (mimeType.startsWith('image/')) {
      return ImageContent(
        data: (this as BlobResourceContents).blob,
        mimeType: mimeType,
      );
    } else if (mimeType.startsWith('audio/')) {
      return AudioContent(
        data: (this as BlobResourceContents).blob,
        mimeType: mimeType,
      );
    } else {
      return TextContent(text: 'Unsupported resource contents type: $this');
    }
  }
}
