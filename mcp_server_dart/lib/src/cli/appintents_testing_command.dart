import 'dart:convert';
import 'dart:io';

import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:path/path.dart' as p;

/// Generates Apple AppIntentsTesting XCTest scaffolds from agent_manifest.json.
Future<int> runAppIntentsTestingGenerate({
  required final String projectRoot,
  required final String manifestPath,
  required final String bundleIdentifier,
  required final String testClassName,
  final String? sampleArgumentsPath,
  final String? entityFixturesPath,
  final String? outputPath,
}) async {
  final bundleId = bundleIdentifier.trim();
  if (bundleId.isEmpty) {
    stderr.writeln(
      'appintents-testing generate failed: --bundle-id is required.',
    );
    return 64;
  }

  final manifestFile = _resolvePath(projectRoot, manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln(
      'appintents-testing generate failed: manifest not found: '
      '${manifestFile.path}',
    );
    return 66;
  }

  try {
    final swift = emitAppIntentsTestingScaffold(
      manifestFile: manifestFile,
      bundleIdentifier: bundleId,
      testClassName: testClassName,
      sampleArgumentsFile: _optionalPath(projectRoot, sampleArgumentsPath),
      entityFixturesFile: _optionalPath(projectRoot, entityFixturesPath),
    );

    final destination = _optionalPath(projectRoot, outputPath);
    if (destination == null) {
      stdout.write(swift);
      stderr.writeln(
        'Proof label: generated AppIntentsTesting scaffold only. '
        'Run it in a signed XCTest UI-test target for runtime proof.',
      );
    } else {
      destination.parent.createSync(recursive: true);
      destination.writeAsStringSync(swift);
      stdout.writeln(
        'OK: wrote AppIntentsTesting XCTest scaffold to ${destination.path}',
      );
      stdout.writeln(
        'Proof label: generated AppIntentsTesting scaffold only. '
        'Run it in a signed XCTest UI-test target for runtime proof.',
      );
    }
    return 0;
  } on FormatException catch (error) {
    stderr.writeln(
      'appintents-testing generate failed: invalid input: ${error.message}',
    );
    return 65;
  } on Object catch (error) {
    stderr.writeln('appintents-testing generate failed: $error');
    return 65;
  }
}

String emitAppIntentsTestingScaffold({
  required final File manifestFile,
  required final String bundleIdentifier,
  required final String testClassName,
  final File? sampleArgumentsFile,
  final File? entityFixturesFile,
}) {
  final manifest = AgentManifest.parse(manifestFile.readAsStringSync());
  return AppleAppIntentsTestingEmitter(
    bundleIdentifier: bundleIdentifier,
    testClassName: testClassName,
    sampleArguments: sampleArgumentsFile == null
        ? const <String, Map<String, Object?>>{}
        : readAppIntentsTestingSampleArguments(sampleArgumentsFile),
    entityFixtures: entityFixturesFile == null
        ? const <String, AppleAppIntentsTestingEntityFixture>{}
        : readAppIntentsTestingEntityFixtures(entityFixturesFile),
  ).emitUiTests(manifest);
}

Map<String, Map<String, Object?>> readAppIntentsTestingSampleArguments(
  final File file,
) {
  final raw = _readJsonObjectFile(file);
  return raw.map((final key, final value) {
    final values = switch (value) {
      final Map<String, Object?> typed => typed,
      final Map map => map.cast<String, Object?>(),
      _ => throw FormatException(
        'sample argument fixture "$key" must be an object.',
      ),
    };
    return MapEntry(key, values);
  });
}

Map<String, AppleAppIntentsTestingEntityFixture>
readAppIntentsTestingEntityFixtures(final File file) {
  final raw = _readJsonObjectFile(file);
  return raw.map((final key, final value) {
    final values = switch (value) {
      final Map<String, Object?> typed => typed,
      final Map map => map.cast<String, Object?>(),
      _ => throw FormatException('entity fixture "$key" must be an object.'),
    };
    final identifier = '${values['identifier'] ?? ''}'.trim();
    final search = '${values['search'] ?? ''}'.trim();
    final expectedTitle = '${values['expectedTitle'] ?? ''}'.trim();
    if (identifier.isEmpty || search.isEmpty || expectedTitle.isEmpty) {
      throw FormatException(
        'entity fixture "$key" requires identifier, search, and expectedTitle.',
      );
    }
    return MapEntry(
      key,
      AppleAppIntentsTestingEntityFixture(
        identifier: identifier,
        search: search,
        expectedTitle: expectedTitle,
      ),
    );
  });
}

Map<String, Object?> _readJsonObjectFile(final File file) {
  if (!file.existsSync()) {
    throw FormatException('JSON file not found: ${file.path}');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  return switch (decoded) {
    final Map<String, Object?> typed => typed,
    final Map map => map.cast<String, Object?>(),
    _ => throw FormatException(
      'JSON file must contain an object: ${file.path}',
    ),
  };
}

File _resolvePath(final String projectRoot, final String path) {
  final normalized = p.normalize(path);
  if (p.isAbsolute(normalized)) {
    return File(normalized);
  }
  return File(p.join(projectRoot, normalized));
}

File? _optionalPath(final String projectRoot, final String? path) {
  final normalized = (path ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return _resolvePath(projectRoot, normalized);
}
