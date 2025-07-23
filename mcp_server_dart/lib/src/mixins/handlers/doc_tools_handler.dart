// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/vm_service_support.dart';
import 'package:flutter_inspector_mcp_server/src/services/dart_vm_doc_service.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
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
  }

  final BaseMCPToolkitServer server;
  final VMServiceSupport vmService;
  late final DartVmDocService _vmDocService;
  late final Logger _logger;

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
          isError: false,
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
          isError: false,
        );
      }
    }

    // 3. pub.dev
    if (effectivePackage.isNotEmpty) {
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
          isError: false,
        );
      }
    }

    return CallToolResult(
      content: [TextContent(text: '{"source":"not_found"}')],
      isError: false,
    );
  }

  /// Handle get_dart_member_doc tool calls (supports VM Service and LSP modes)
  FutureOr<CallToolResult> handleGetDartMemberDoc(
    final CallToolRequest request,
  ) async {
    final args = request.arguments;
    final member = jsonDecodeString(args?['member']);
    final isolateId = jsonDecodeString(args?['isolate_id']);
    final filePath = jsonDecodeString(args?['file_path']);
    final line = jsonDecodeInt(args?['line']);
    final character = jsonDecodeInt(args?['character']);

    if (member.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'Member name is required')],
        isError: true,
      );
    }

    try {
      // If specific position is provided, use LSP hover
      if (filePath.isNotEmpty && !line.isZero && !character.isZero) {
        return await _handleHoverBasedExtraction(filePath, line, character);
      }

      // Auto-discover member location if not explicitly provided
      MemberLocation? location;
      if (filePath.isEmpty || line.isZero || character.isZero) {
        _logger.info('Auto-discovering location for member: $member');
        location = await _findMemberInProject(member);

        if (location == null) {
          return CallToolResult(
            content: [
              TextContent(
                text:
                    'Member "$member" not found in current project.\n\n'
                    'Searched in all .dart files in the current directory and subdirectories.\n'
                    'Make sure:\n'
                    '1. The member name is spelled correctly\n'
                    '2. The member is defined in a .dart file in this project\n'
                    '3. You are running this from the project root directory',
              ),
            ],
            isError: false,
          );
        }

        _logger.info('Found member at: $location');

        // Use discovered location for hover-based extraction
        return await _handleHoverBasedExtraction(
          location.filePath,
          location.line,
          location.character,
        );
      }

      // Otherwise use member-based extraction with LSP fallback
      return await _handleMemberBasedExtraction(
        member,
        isolateId,
        filePath: filePath.isEmpty ? null : filePath,
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error extracting documentation: $e')],
        isError: true,
      );
    }
  }

  /// Handle get_dart_hover_doc tool calls
  FutureOr<CallToolResult> handleGetDartHoverDoc(
    final CallToolRequest request,
  ) async {
    final args = request.arguments;
    final filePath = jsonDecodeString(args?['file_path']);
    final line = jsonDecodeInt(args?['line']);
    final character = jsonDecodeInt(args?['character']);

    if (filePath.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'file_path parameter is required')],
        isError: true,
      );
    }

    if (line.isZero || character.isZero) {
      return CallToolResult(
        content: [
          TextContent(text: 'line and character parameters are required'),
        ],
        isError: true,
      );
    }

    try {
      return await _handleHoverBasedExtraction(filePath, line, character);
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error getting hover documentation: $e')],
        isError: true,
      );
    }
  }

  /// Handle hover-based documentation extraction using LSP
  Future<CallToolResult> _handleHoverBasedExtraction(
    final String filePath,
    final int line,
    final int character,
  ) async {
    try {
      final documentation = await _vmDocService.getHoverDocumentation(
        filePath,
        line,
        character,
      );

      if (documentation != null && documentation.isNotEmpty) {
        return CallToolResult(content: [TextContent(text: documentation)]);
      } else {
        return CallToolResult(
          content: [
            TextContent(
              text:
                  'No documentation found at position $line:$character in $filePath.\n\n'
                  'Make sure:\n'
                  '1. The file path is correct\n'
                  '2. The position contains a valid Dart symbol\n'
                  '3. The Dart analysis server is accessible',
            ),
          ],
        );
      }
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error getting hover documentation: $e')],
        isError: true,
      );
    }
  }

  /// Handle member name-based documentation extraction (VM Service with LSP fallback)
  Future<CallToolResult> _handleMemberBasedExtraction(
    final String member,
    final String? isolateId, {
    final String? filePath,
  }) async {
    try {
      // Ensure VM service is connected
      final connected = await vmService.ensureVMServiceConnected();
      if (!connected) {
        return CallToolResult(
          content: [
            TextContent(
              text:
                  'No VM Service connection. Please ensure a Flutter/Dart app is running in debug mode.',
            ),
          ],
          isError: true,
        );
      }

      final vmServiceInstance = vmService.vmService!;

      // Get the documentation using the VM service with LSP fallback
      final documentation = await _vmDocService.getMemberDocumentation(
        member,
        vmServiceInstance,
        isolateId: isolateId,
        filePath: filePath,
      );

      if (documentation != null && documentation.isNotEmpty) {
        return CallToolResult(content: [TextContent(text: documentation)]);
      } else {
        return CallToolResult(
          content: [
            TextContent(
              text:
                  'No documentation found for member "$member".\n\n'
                  'Make sure:\n'
                  '1. The member name is correct\n'
                  '2. The Flutter/Dart app is running\n'
                  '3. The member is loaded in the current app context',
            ),
          ],
        );
      }
    } catch (e) {
      return CallToolResult(
        content: [
          TextContent(text: 'Error getting documentation for "$member": $e'),
        ],
        isError: true,
      );
    }
  }

  /// Automatically find a Dart member in the current project
  Future<MemberLocation?> _findMemberInProject(final String memberName) async {
    try {
      final currentDir = Directory.current;
      final dartFiles = await _findDartFiles(currentDir);

      _logger.info(
        'Searching for "$memberName" in ${dartFiles.length} Dart files',
      );

      for (final file in dartFiles) {
        final location = await _searchMemberInFile(file, memberName);
        if (location != null) {
          return location;
        }
      }

      return null;
    } catch (e) {
      _logger.severe('Error finding member in project: $e');
      return null;
    }
  }

  /// Recursively find all .dart files in the project
  Future<List<File>> _findDartFiles(final Directory directory) async {
    final dartFiles = <File>[];

    try {
      final entities = directory.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.dart')) {
          // Skip generated files and common exclusions
          final relativePath = p.relative(
            entity.path,
            from: Directory.current.path,
          );
          if (!_shouldSkipFile(relativePath)) {
            dartFiles.add(entity);
          }
        }
      }
    } catch (e) {
      _logger.warning('Error listing files in ${directory.path}: $e');
    }

    return dartFiles;
  }

  /// Check if a file should be skipped during search
  bool _shouldSkipFile(final String relativePath) {
    final skipPatterns = [
      '.dart_tool/',
      'build/',
      '.pub-cache/',
      'android/',
      'ios/',
      'linux/',
      'macos/',
      'web/',
      'windows/',
      '.freezed.dart',
      '.g.dart',
      '.gr.dart',
      'generated_plugin_registrant.dart',
    ];

    return skipPatterns.any(relativePath.contains);
  }

  /// Search for a specific member in a Dart file
  Future<MemberLocation?> _searchMemberInFile(
    final File file,
    final String memberName,
  ) async {
    try {
      final content = await file.readAsString();
      final lines = content.split('\n');

      // Define regex patterns for different member types
      final patterns = [
        // Class definitions
        RegExp(
          r'^\s*(?:abstract\s+)?class\s+' + RegExp.escape(memberName) + r'\b',
          multiLine: true,
        ),
        // Mixin definitions
        RegExp(
          r'^\s*mixin\s+' + RegExp.escape(memberName) + r'\b',
          multiLine: true,
        ),
        // Enum definitions
        RegExp(
          r'^\s*enum\s+' + RegExp.escape(memberName) + r'\b',
          multiLine: true,
        ),
        // Extension definitions
        RegExp(
          r'^\s*extension\s+' + RegExp.escape(memberName) + r'\b',
          multiLine: true,
        ),
        // Function definitions (top-level)
        RegExp(
          r'^\s*(?:[\w<>?,\s]+\s+)?' + RegExp.escape(memberName) + r'\s*\(',
          multiLine: true,
        ),
        // Method definitions (within class)
        RegExp(
          r'^\s*(?:[\w<>?,\s]+\s+)?' + RegExp.escape(memberName) + r'\s*\(',
          multiLine: true,
        ),
        // Variable/field definitions
        RegExp(
          r'^\s*(?:final\s+|var\s+|const\s+|static\s+)*(?:[\w<>?,\s]+\s+)?' +
              RegExp.escape(memberName) +
              r'\s*[=;]',
          multiLine: true,
        ),
        // Typedef definitions
        RegExp(
          r'^\s*typedef\s+' + RegExp.escape(memberName) + r'\b',
          multiLine: true,
        ),
      ];

      for (int i = 0; i < patterns.length; i++) {
        final pattern = patterns[i];
        final match = pattern.firstMatch(content);

        if (match != null) {
          final matchStart = match.start;
          final lineNumber =
              content.substring(0, matchStart).split('\n').length - 1;
          final lineStart =
              lineNumber == 0
                  ? 0
                  : content.lastIndexOf('\n', matchStart - 1) + 1;
          final character = matchStart - lineStart;

          final memberType = _determineMemberType(match.group(0) ?? '');

          return MemberLocation(
            filePath: file.path,
            line: lineNumber,
            character: character,
            memberType: memberType,
            fullMatch: match.group(0) ?? '',
          );
        }
      }

      return null;
    } catch (e) {
      _logger.warning('Error searching in file ${file.path}: $e');
      return null;
    }
  }

  /// Determine the type of member based on the matched text
  String _determineMemberType(final String matchText) {
    final trimmed = matchText.trim().toLowerCase();

    if (trimmed.startsWith('class')) return 'class';
    if (trimmed.startsWith('abstract class')) return 'abstract class';
    if (trimmed.startsWith('mixin')) return 'mixin';
    if (trimmed.startsWith('enum')) return 'enum';
    if (trimmed.startsWith('extension')) return 'extension';
    if (trimmed.startsWith('typedef')) return 'typedef';
    if (trimmed.contains('(')) {
      if (trimmed.startsWith('static') ||
          matchText.trim().contains(' static ')) {
        return 'static method';
      }
      return 'function/method';
    }
    if (trimmed.startsWith('final')) return 'final field';
    if (trimmed.startsWith('const')) return 'const field';
    if (trimmed.startsWith('var')) return 'variable';
    if (trimmed.startsWith('static')) return 'static field';

    return 'member';
  }
}
