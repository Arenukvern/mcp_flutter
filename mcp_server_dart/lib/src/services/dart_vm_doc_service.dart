// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:io'; // Added for File

import 'package:flutter_inspector_mcp_server/src/services/dart_lsp_client.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

/// Service for getting Dart member documentation via VM Service Protocol and LSP
@immutable
final class DartVmDocService {
  /// Creates a new [DartVmDocService] instance
  const DartVmDocService({
    required this.logger,
    this.timeout = const Duration(seconds: 30),
    this.enableLspFallback = true,
  });

  /// Logger for VM service operations
  final Logger logger;

  /// Timeout for VM service operations
  final Duration timeout;

  /// Whether to use LSP as fallback when VM service fails
  final bool enableLspFallback;

  /// Cache for documentation responses
  static final Map<String, String> _docCache = {};

  /// LSP client instance (lazy initialized)
  static DartLspClient? _lspClient;

  /// Get documentation for a Dart member using VM Service Protocol with LSP fallback
  ///
  /// [member] - The member name to look up (class, function, etc.)
  /// [vmService] - The VM service connection to use
  /// [isolateId] - Optional isolate ID, will use main isolate if not provided
  /// [filePath] - Optional file path for LSP-based lookup
  ///
  /// Returns the documentation string or null if not found
  Future<String?> getMemberDocumentation(
    final String member,
    final VmService vmService, {
    final String? isolateId,
    final String? filePath,
  }) async {
    final cacheKey = '${isolateId ?? 'main'}::$member';
    if (_docCache.containsKey(cacheKey)) {
      return _docCache[cacheKey];
    }

    try {
      // First try VM Service approach
      final vmDoc = await _getVmServiceDocumentation(
        member,
        vmService,
        isolateId: isolateId,
      );

      if (vmDoc != null && vmDoc.isNotEmpty) {
        _docCache[cacheKey] = vmDoc;
        return vmDoc;
      }

      // Fallback to LSP approach if enabled and file path provided
      if (enableLspFallback && filePath != null) {
        final lspDoc = await _getLspDocumentation(member, filePath);
        if (lspDoc != null && lspDoc.isNotEmpty) {
          _docCache[cacheKey] = lspDoc;
          return lspDoc;
        }
      }

      logger.info('No documentation found for member: $member');
      return null;
    } catch (e, stackTrace) {
      logger.severe(
        'Error getting documentation for member: $member',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Get documentation using LSP approach
  Future<String?> _getLspDocumentation(
    final String member,
    final String filePath,
  ) async {
    try {
      // Initialize LSP client if needed
      _lspClient ??= DartLspClient(logger: logger);

      if (!_lspClient!.isInitialized) {
        final started = await _lspClient!.start();
        if (!started) {
          logger.warning('Failed to start LSP client');
          return null;
        }
      }

      // Try to find symbol documentation
      final doc = await _lspClient!.findSymbolDocumentation(filePath, member);
      if (doc != null) {
        return '## LSP Documentation\n\n$doc';
      }

      return null;
    } catch (e) {
      logger.warning('Error getting LSP documentation: $e');
      return null;
    }
  }

  /// Get documentation using VM Service approach (existing implementation)
  Future<String?> _getVmServiceDocumentation(
    final String member,
    final VmService vmService, {
    final String? isolateId,
  }) async {
    try {
      // Get the main isolate if not provided
      final effectiveIsolateId =
          isolateId ?? await _getMainIsolateId(vmService);
      if (effectiveIsolateId == null) {
        logger.warning('No isolate available for documentation lookup');
        return null;
      }

      // First try to find the member as a class
      final classDoc = await _getClassDocumentation(
        vmService,
        effectiveIsolateId,
        member,
      );

      if (classDoc != null) {
        return classDoc;
      }

      // Then try to find it as a library member
      final libraryDoc = await _getLibraryMemberDocumentation(
        vmService,
        effectiveIsolateId,
        member,
      );

      return libraryDoc;
    } catch (e) {
      logger.warning('Error getting VM service documentation: $e');
      return null;
    }
  }

  /// Get hover documentation at specific position using LSP
  ///
  /// [filePath] - Path to the Dart file
  /// [line] - Line number (0-based)
  /// [character] - Character position (0-based)
  ///
  /// Returns hover documentation or null
  Future<String?> getHoverDocumentation(
    final String filePath,
    final int line,
    final int character,
  ) async {
    if (!enableLspFallback) return null;

    try {
      _lspClient ??= DartLspClient(logger: logger);

      if (!_lspClient!.isInitialized) {
        final started = await _lspClient!.start();
        if (!started) return null;
      }

      return await _lspClient!.getHover(filePath, line, character);
    } catch (e) {
      logger.warning('Error getting hover documentation: $e');
      return null;
    }
  }

  /// Shutdown LSP client
  static Future<void> shutdownLspClient() async {
    if (_lspClient != null) {
      await _lspClient!.shutdown();
      _lspClient = null;
    }
  }

  /// Get the main isolate ID
  Future<String?> _getMainIsolateId(final VmService vmService) async {
    try {
      final vm = await vmService.getVM();
      if (vm.isolates?.isNotEmpty ?? false) {
        return vm.isolates!.first.id;
      }
    } catch (e) {
      logger.warning('Failed to get main isolate: $e');
    }
    return null;
  }

  /// Get documentation for a class using VM Service
  Future<String?> _getClassDocumentation(
    final VmService vmService,
    final String isolateId,
    final String className,
  ) async {
    try {
      // Get all classes in the isolate
      final classListResponse = await vmService.getClassList(isolateId);
      final classes = classListResponse.classes ?? [];

      // Find the class by name
      final classRef =
          classes.where((final c) => c.name == className).firstOrNull;
      if (classRef?.id == null) {
        return null;
      }

      // Get detailed class information
      final classObj = await vmService.getObject(isolateId, classRef!.id!);
      if (classObj is Class) {
        return await _extractDocumentationFromClass(classObj);
      }
    } catch (e) {
      logger.warning('Error getting class documentation for $className: $e');
    }
    return null;
  }

  /// Get documentation for a library member
  Future<String?> _getLibraryMemberDocumentation(
    final VmService vmService,
    final String isolateId,
    final String memberName,
  ) async {
    try {
      // Get isolate information to access libraries
      final isolate = await vmService.getIsolate(isolateId);
      final libraries = isolate.libraries ?? [];

      // Search through all libraries for the member
      for (final libRef in libraries) {
        if (libRef.id == null) continue;

        final library = await vmService.getObject(isolateId, libRef.id!);
        if (library is! Library) continue;

        // Check library functions
        final functions = library.functions ?? [];
        final functionRef =
            functions.where((final f) => f.name == memberName).firstOrNull;

        if (functionRef?.id != null) {
          final function = await vmService.getObject(
            isolateId,
            functionRef!.id!,
          );
          if (function is Func) {
            return _extractDocumentationFromFunction(function, library);
          }
        }

        // Check library variables
        final variables = library.variables ?? [];
        final variableRef =
            variables.where((final v) => v.name == memberName).firstOrNull;

        if (variableRef?.id != null) {
          final variable = await vmService.getObject(
            isolateId,
            variableRef!.id!,
          );
          if (variable is Field) {
            return _extractDocumentationFromField(variable, library);
          }
        }
      }
    } catch (e) {
      logger.warning(
        'Error getting library member documentation for $memberName: $e',
      );
    }
    return null;
  }

  /// Extract documentation from a Class object using its source location
  Future<String?> _extractDocumentationFromClass(final Class classObj) async {
    try {
      // First try to get documentation from the source location
      final location = classObj.location;
      if (location?.script?.uri != null && location?.tokenPos != null) {
        final sourceDoc = await _getDocumentationFromLocation(
          location!.script!.uri!,
          location.tokenPos!,
          classObj.name,
        );
        if (sourceDoc != null && sourceDoc.isNotEmpty) {
          return sourceDoc;
        }
      }

      // Fallback to basic class metadata if location-based extraction fails
      return _getBasicClassInfo(classObj);
    } catch (e) {
      logger.warning(
        'Failed to extract documentation for class ${classObj.name}: $e',
      );
      return _getBasicClassInfo(classObj);
    }
  }

  /// Get documentation from source file at the given location
  Future<String?> _getDocumentationFromLocation(
    final String uri,
    final int tokenPos, [
    final String? className,
  ]) async {
    try {
      // Convert VM service URI to file path
      final filePath = _uriToFilePath(uri);
      if (filePath == null) return null;

      final file = File(filePath);
      if (!file.existsSync()) return null;

      final content = await file.readAsString();
      final lines = content.split('\n');

      // Find the line number from token position (approximation)
      // Token positions are character offsets, so we need to convert to line numbers
      int charOffset = 0;
      int lineNumber = 0;

      for (int i = 0; i < lines.length; i++) {
        final lineLength = lines[i].length + 1; // +1 for newline
        if (charOffset + lineLength > tokenPos) {
          lineNumber = i;
          break;
        }
        charOffset += lineLength;
      }

      // Extract documentation comments above the definition
      return _extractDocCommentsAboveLine(lines, lineNumber, className);
    } catch (e) {
      logger.warning('Failed to read documentation from location $uri: $e');
      return null;
    }
  }

  /// Extract documentation comments from lines above the target line
  String? _extractDocCommentsAboveLine(
    final List<String> lines,
    final int targetLine, [
    final String? className,
  ]) {
    final docLines = <String>[];

    // Look backwards from target line to find documentation comments
    for (int i = targetLine - 1; i >= 0; i--) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        // Empty line - continue looking backwards
        continue;
      } else if (line.startsWith('///')) {
        // Triple slash comment
        docLines.insert(0, line.substring(3).trim());
      } else if (line.startsWith('/**') && line.endsWith('*/')) {
        // Single line block comment
        final content = line.substring(3, line.length - 2).trim();
        docLines.insert(0, content);
        break;
      } else if (line.startsWith('/**')) {
        // Start of multi-line block comment
        final content = line.substring(3).trim();
        if (content.isNotEmpty) docLines.insert(0, content);

        // Look for continuation lines
        for (int j = i + 1; j < targetLine; j++) {
          final blockLine = lines[j].trim();
          if (blockLine.endsWith('*/')) {
            final blockContent =
                blockLine.substring(0, blockLine.length - 2).trim();
            if (blockContent.startsWith('*')) {
              docLines.add(blockContent.substring(1).trim());
            } else if (blockContent.isNotEmpty) {
              docLines.add(blockContent);
            }
            break;
          } else if (blockLine.startsWith('*')) {
            docLines.add(blockLine.substring(1).trim());
          } else if (blockLine.isNotEmpty) {
            docLines.add(blockLine);
          }
        }
        break;
      } else {
        // Non-comment line - stop looking
        break;
      }
    }

    if (docLines.isEmpty) return null;

    // Format the extracted documentation
    final docs = <String>[];
    docs.add('## ${className ?? 'Class'}');
    docs.add('');
    docs.addAll(docLines);

    return docs.join('\n');
  }

  /// Convert VM service URI to local file path
  String? _uriToFilePath(final String uri) {
    try {
      final parsedUri = Uri.parse(uri);
      if (parsedUri.scheme == 'file') {
        return parsedUri.toFilePath();
      }
      // Handle other URI schemes if needed (e.g., package: URIs)
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get basic class information as fallback
  String _getBasicClassInfo(final Class classObj) {
    final docs = <String>[];

    // Add class name and basic info
    docs.add('## Class: ${classObj.name ?? 'Unknown'}');

    // Add class library information
    if (classObj.library?.name != null) {
      docs.add('**Library**: `${classObj.library!.name}`');
    }

    // Add superclass information
    if (classObj.superClass?.name != null) {
      docs.add('**Extends**: `${classObj.superClass!.name}`');
    }

    // Add interfaces
    final interfaces = classObj.interfaces ?? [];
    if (interfaces.isNotEmpty) {
      final interfaceNames = interfaces
          .where((final i) => i.name != null)
          .map((final i) => '`${i.name}`')
          .join(', ');
      docs.add('**Implements**: $interfaceNames');
    }

    // Add fields count
    final fields = classObj.fields ?? [];
    if (fields.isNotEmpty) {
      docs.add('**Fields**: ${fields.length}');
    }

    // Add functions count
    final functions = classObj.functions ?? [];
    if (functions.isNotEmpty) {
      docs.add('**Methods**: ${functions.length}');
    }

    return docs.join('\n');
  }

  /// Extract documentation from a Function object
  String? _extractDocumentationFromFunction(
    final Func function,
    final Library library,
  ) {
    final docs = <String>[];

    // Add function name and basic info
    docs.add('## Function: ${function.name ?? 'Unknown'}');

    // Add library information
    if (library.name != null) {
      docs.add('**Library**: `${library.name}`');
    }

    // Add signature information if available
    if (function.signature != null) {
      docs.add('**Signature**: `${function.signature!.name ?? 'Unknown'}`');
    }

    // Add static/instance information
    if (function.isStatic == true) {
      docs.add('**Type**: Static function');
    } else {
      docs.add('**Type**: Instance function');
    }

    // Add const information
    if (function.isConst == true) {
      docs.add('**Modifier**: const');
    }

    return docs.join('\n\n');
  }

  /// Extract documentation from a Field object
  String? _extractDocumentationFromField(
    final Field field,
    final Library library,
  ) {
    final docs = <String>[];

    // Add field name and basic info
    docs.add('## Field: ${field.name ?? 'Unknown'}');

    // Add library information
    if (library.name != null) {
      docs.add('**Library**: `${library.name}`');
    }

    // Add static/instance information
    if (field.isStatic == true) {
      docs.add('**Type**: Static field');
    } else {
      docs.add('**Type**: Instance field');
    }

    // Add final/const information
    if (field.isFinal == true) {
      docs.add('**Modifier**: final');
    }
    if (field.isConst == true) {
      docs.add('**Modifier**: const');
    }

    // Add declared type if available
    if (field.declaredType?.name != null) {
      docs.add('**Declared Type**: `${field.declaredType!.name}`');
    }

    return docs.join('\n\n');
  }

  /// Clear the documentation cache
  static void clearCache() {
    _docCache.clear();
  }
}
