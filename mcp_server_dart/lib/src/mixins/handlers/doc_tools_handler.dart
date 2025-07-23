// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/vm_service_support.dart';
import 'package:flutter_inspector_mcp_server/src/services/dart_vm_doc_service.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:github/github.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Represents a discovered member location in the project
class MemberLocation {
  const MemberLocation({
    required this.filePath,
    required this.line,
    required this.character,
    required this.memberType,
    required this.fullMatch,
  });

  final String filePath;
  final int line;
  final int character;
  final String memberType; // 'class', 'function', 'method', 'variable', etc.
  final String fullMatch;

  @override
  String toString() =>
      'MemberLocation(file: $filePath, line: $line, char: $character, type: $memberType)';
}

/// Handles documentation-related tools and functionality for the Flutter Inspector.
class DocToolsHandler {
  /// Creates a new [DocToolsHandler] instance.
  DocToolsHandler({required this.server, required this.vmService}) {
    // Initialize the VM documentation service
    _vmDocService = DartVmDocService(logger: Logger('DocToolsHandler'));
    _logger = Logger('DocToolsHandler');
    _github = GitHub();
  }
  late final GitHub _github;
  final BaseMCPToolkitServer server;
  final VMServiceSupport vmService;
  late final DartVmDocService _vmDocService;
  late final Logger _logger;
  void dispose() {
    _github.dispose();
  }

  /// Check if a package exists on pub.dev using the official API
  Future<bool> _packageExistsOnPubDev(final String packageName) async {
    try {
      // Use the official pub.dev API to check package existence
      final response = await http.get(
        Uri.parse('https://pub.dev/api/packages/$packageName'),
        headers: {'accept-encoding': 'gzip'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get package info from pub.dev using the official Hosted Pub Repository API
  Future<Map<String, dynamic>?> _getPackageInfoFromPubDev(
    final String packageName,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('https://pub.dev/api/packages/$packageName'),
        headers: {'accept-encoding': 'gzip'},
      );
      if (response.statusCode == 200) {
        return jsonDecodeMapAs<String, dynamic>(response.body);
      }
    } catch (_) {}
    return null;
  }

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

  /// Tool to get Dart member documentation using VM Service and LSP
  static final getDartMemberDoc = Tool(
    name: 'get_dart_member_doc',
    description:
        'Get the documentation for a Dart member (class, function, etc.) from the running Flutter/Dart app using VM Service Protocol with LSP fallback. **Auto-discovery**: Just provide the member name and the tool will automatically find its location in the current project. Supports both VM Service (for running apps) and LSP (for static analysis).',
    inputSchema: ObjectSchema(
      properties: {
        'member': Schema.string(
          description:
              'The Dart member name (class, function, etc.) to fetch documentation for. The tool will automatically search for this member in all .dart files in the current project.',
        ),
        'isolate_id': Schema.string(
          description:
              'Optional: Specific isolate ID to search in. Uses main isolate if not provided.',
        ),
        'file_path': Schema.string(
          description:
              'Optional: Path to Dart file for LSP-based lookup. If not provided, the tool will automatically search for the member in the project.',
        ),
        'line': Schema.int(
          description:
              'Optional: Line number (0-based) for precise hover documentation via LSP. If not provided, the tool will automatically locate the member.',
        ),
        'character': Schema.int(
          description:
              'Optional: Character position (0-based) for precise hover documentation via LSP. If not provided, the tool will automatically locate the member.',
        ),
      },
    ),
  );

  /// Tool to get hover documentation at specific position using LSP
  static final getDartHoverDoc = Tool(
    name: 'get_dart_hover_doc',
    description:
        'Get hover documentation for a Dart symbol at a specific position using the Dart LSP server. Provides precise documentation, type info, and signature help.',
    inputSchema: ObjectSchema(
      properties: {
        'file_path': Schema.string(
          description: 'Path to the Dart file containing the symbol',
        ),
        'line': Schema.int(
          description: 'Line number (0-based) where the symbol is located',
        ),
        'character': Schema.int(
          description:
              'Character position (0-based) within the line where the symbol starts',
        ),
      },
      required: ['file_path', 'line', 'character'],
    ),
  );

  /// Handle get_pub_doc tool calls
  FutureOr<CallToolResult> handleGetPubDoc(
    final CallToolRequest request,
  ) async {
    final args = request.arguments;
    final package = jsonDecodeString(args?['package']);
    final fvmSdkPath = jsonDecodeString(args?['fvm_sdk_path']);
    final gitPathArg = jsonDecodeString(args?['git_path']);
    final localPathArg = jsonDecodeString(args?['local_path']);
    final pubspecPath = jsonDecodeString(
      args?['pubspec_path'],
    ).whenEmptyUse('pubspec.yaml');
    String? resolvedLocalPath;
    String? resolvedGitPath;
    String? resolvedPackage;

    // 1. Try to parse pubspec.yaml if package is provided and no manual path overrides
    if (package.isNotEmpty && (gitPathArg.isEmpty) && (localPathArg.isEmpty)) {
      try {
        final pubspecFile = File(pubspecPath);
        if (pubspecFile.existsSync()) {
          final pubspecContent = pubspecFile.readAsStringSync();
          final pubspec = loadYaml(pubspecContent) as YamlMap;
          // Check both dependencies and dev_dependencies
          final deps = pubspec['dependencies'] as YamlMap?;
          final devDeps = pubspec['dev_dependencies'] as YamlMap?;
          final dep =
              (deps != null ? deps[package] : null) ??
              (devDeps != null ? devDeps[package] : null);

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

    if ((effectivePackage.isEmpty) &&
        (gitPath.isEmpty) &&
        (localPath.isEmpty)) {
      return CallToolResult(
        content: [
          TextContent(text: 'No package, git_path, or local_path provided.'),
        ],
        isError: true,
      );
    }

    // Priority: local_path > git_path > pub.dev > pub cache
    // 1. Local path
    if (localPath.isNotEmpty) {
      final readmeFile = File(p.join(localPath, 'README.md'));
      if (readmeFile.existsSync()) {
        final content = readmeFile.readAsStringSync();
        return CallToolResult(
          content: [
            TextContent(text: content),
            TextContent(text: '{"source":"local_path"}'),
          ],
        );
      }
    }

    // 2. Git path
    if (gitPath.isNotEmpty) {
      final readmeFile = File(p.join(gitPath, 'README.md'));
      if (readmeFile.existsSync()) {
        final content = readmeFile.readAsStringSync();
        return CallToolResult(
          content: [
            TextContent(text: content),
            TextContent(text: '{"source":"git"}'),
          ],
        );
      }
    }
    // 3. pub.dev
    if (effectivePackage.isNotEmpty) {
      // First check if package exists on pub.dev using official API
      final packageExists = await _packageExistsOnPubDev(effectivePackage);

      if (packageExists) {
        // Try to get the latest version's README
        try {
          final readmeUrl =
              'https://pub.dev/documentation/$effectivePackage/latest/';
          final response = await http.get(Uri.parse(readmeUrl));

          if (response.statusCode == 200) {
            final document = parse(response.body);
            final readme = document.getElementById('dartdoc-main-content');
            if (readme != null) {
              // Extract the README in markdown-like format, preserving text order
              // dartdoc-main-content may contain HTML, so walk children in order
              final StringBuffer markdown = StringBuffer();
              for (final node in readme.children) {
                final tag = node.localName;
                if (tag == 'pre') {
                  markdown.writeln('```\n${node.text.trim()}\n```');
                  markdown.writeln();
                } else if (tag == 'p' ||
                    tag == 'h1' ||
                    tag == 'h2' ||
                    tag == 'h3' ||
                    tag == 'h4' ||
                    tag == 'h5' ||
                    tag == 'h6') {
                  markdown.writeln(node.text.trim());
                  markdown.writeln();
                } else if (tag == 'ul' || tag == 'ol') {
                  for (final li in node.children.where(
                    (final c) => c.localName == 'li',
                  )) {
                    markdown.writeln('- ${li.text.trim()}');
                  }
                  markdown.writeln();
                }
              }
              // Fallback: if markdown is empty, use the full text
              final result =
                  markdown.toString().trim().isEmpty
                      ? readme.text.trim()
                      : markdown.toString().trim();
              return CallToolResult(content: [TextContent(text: result)]);
            }
          }
        } catch (e, s) {
          _logger.severe('Error getting README from pub.dev: $e', s);
          return CallToolResult(
            content: [
              TextContent(text: 'Error getting README from pub.dev: $e'),
            ],
            isError: true,
          );
        }
      }
      // 4. Fallback: try local pub cache
      String pubCache;
      if (fvmSdkPath.isNotEmpty) {
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
        );
      }
    }

    return CallToolResult(
      content: [TextContent(text: '{"source":"not_found"}')],
      isError: false,
    );
  }
}
