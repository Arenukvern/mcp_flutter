// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Handles documentation-related tools and functionality for the Flutter Inspector.
class DocToolsHandler {
  /// Creates a new [DocToolsHandler] instance.
  DocToolsHandler({required this.server});

  final BaseMCPToolkitServer server;

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

  /// Handle get_pub_doc tool calls
  FutureOr<CallToolResult> handleGetPubDoc(
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
      content: [TextContent(text: '{"source":"not_found"}')],
      isError: false,
    );
  }

  /// Handle get_dart_member_doc tool calls
  FutureOr<CallToolResult> handleGetDartMemberDoc(
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
