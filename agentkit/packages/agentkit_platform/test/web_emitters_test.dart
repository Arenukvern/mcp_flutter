import 'dart:convert';

import 'package:agentkit_platform/agentkit_platform.dart';
import 'package:test/test.dart';

void main() {
  group('WebManifestEmitter', () {
    test('patches shortcuts and protocol_handlers from agent manifest', () {
      const baseManifest = '''
{
    "name": "demo",
    "short_name": "demo",
    "start_url": "."
}
''';
      final agentManifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_cart_total',
            'namespace': 'app',
            'name': 'cart_total',
            'description': 'Return cart total',
            'kind': 'tool',
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      final output = const WebManifestEmitter().emit(
        existingManifestJson: baseManifest,
        manifest: agentManifest,
      );
      final map = jsonDecode(output) as Map<String, Object?>;
      final shortcuts =
          (map['shortcuts']! as List).cast<Map<String, Object?>>();
      expect(shortcuts, hasLength(1));
      expect(shortcuts.first['url'], '/agent/invoke?name=app_cart_total');

      final handlers =
          (map['protocol_handlers']! as List).cast<Map<String, Object?>>();
      expect(handlers, isNotEmpty);
      expect(handlers.first['protocol'], 'web+agentkit');
      expect(map['name'], 'demo');
    });

    test('matches golden manifest output', () {
      final output = const WebManifestEmitter().emit(
        existingManifestJson: _fixtureBaseWebManifest,
        manifest: _fixtureAgentManifest,
      );
      expect(output.trim(), _goldenWebManifest.trim());
    });
  });

  group('WebMcpJsEmitter', () {
    test('emits feature-detect registerTool loop', () {
      final js = const WebMcpJsEmitter().emit(_fixtureAgentManifest);
      expect(js, contains("'modelContext' in nav"));
      expect(js, contains('registerTool'));
      expect(js, contains('app_cart_total'));
      expect(js, contains('encodeURIComponent(name)'));
      expect(js, contains('application/json'));
      expect(js, contains('__agentkitWebMcpDartExecute'));
      expect(js, contains('validateInput'));
      expect(js, contains('Unknown property'));
      expect(js, contains('validateValue'));
    });

    test('emits array items object validation', () {
      final js = const WebMcpJsEmitter().emit(_fixtureAgentManifest);
      expect(js, contains('validateArrayItems'));
      expect(js, contains('validateObjectProperties'));
      expect(js, contains('must be an object.'));
      expect(js, contains('Missing required property "'));
    });

    test('emits additionalProperties guard in validateInput', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_strict',
            'namespace': 'app',
            'name': 'strict',
            'description': 'strict schema',
            'kind': 'tool',
            'inputSchema': <String, Object?>{
              'type': 'object',
              'additionalProperties': false,
              'properties': <String, Object?>{
                'n': <String, Object?>{
                  'type': 'integer',
                  'minimum': 0,
                  'maximum': 10,
                },
              },
            },
          },
        ],
      });
      final js = const WebMcpJsEmitter().emit(manifest);
      expect(js, contains('additionalProperties === false'));
      expect(js, contains('Unknown property'));
      expect(js, contains('validateNumericBounds'));
    });

    test('matches golden js output', () {
      final js = const WebMcpJsEmitter().emit(_fixtureAgentManifest);
      expect(js, _goldenWebMcpJs);
    });

    test('skips non-tool intents', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_errors',
            'namespace': 'app',
            'name': 'errors',
            'description': 'errors resource',
            'kind': 'resource',
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });
      final js = const WebMcpJsEmitter().emit(manifest);
      expect(js, isNot(contains('app_errors')));
      expect(js, contains('var tools = ['));
      expect(js, contains('];'));
      expect(js.split('var tools = [').last.split('];').first.trim(), isEmpty);
    });
  });

  group('AgentManifest', () {
    test('reads shortcuts and intents arrays', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'android',
        'shortcuts': [
          <String, Object?>{
            'qualifiedName': 'app_ping',
            'namespace': 'app',
            'name': 'ping',
            'description': 'ping',
            'kind': 'tool',
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });
      expect(manifest.entries, hasLength(1));
      expect(manifest.tools.first.qualifiedName, 'app_ping');
    });
  });
}

const _fixtureBaseWebManifest = '''
{
    "name": "test_app",
    "short_name": "test_app",
    "start_url": ".",
    "display": "standalone"
}
''';

final _fixtureAgentManifest = AgentManifest.fromJson(<String, Object?>{
  'version': 1,
  'platform': 'web',
  'tools': [
    <String, Object?>{
      'qualifiedName': 'app_cart_total',
      'namespace': 'app',
      'name': 'cart_total',
      'description': 'Return cart total',
      'kind': 'tool',
      'inputSchema': <String, Object?>{'type': 'object'},
    },
  ],
});

const _goldenWebManifest = '''
{
    "name": "test_app",
    "short_name": "test_app",
    "start_url": ".",
    "display": "standalone",
    "shortcuts": [
        {
            "name": "Cart Total",
            "short_name": "Cart Total",
            "description": "Return cart total",
            "url": "/agent/invoke?name=app_cart_total"
        }
    ],
    "protocol_handlers": [
        {
            "protocol": "web+agentkit",
            "url": "/agent/invoke?protocol=%s"
        },
        {
            "protocol": "web+agentkit",
            "url": "/agent/invoke?name=app_cart_total&payload=%s"
        }
    ]
}''';

const _goldenWebMcpJs = '''
// Generated by agentkit_platform — do not edit by hand.
(function agentkitWebMcpBootstrap(global) {
  'use strict';
  var nav = global.navigator;
  if (!nav || !('modelContext' in nav) || typeof nav.modelContext.registerTool !== 'function') {
    return;
  }
  var invokePath = "/agent/invoke";
  var tools = [
  {
    "name": "app_cart_total",
    "description": "Return cart total",
    "inputSchema": {
      "type": "object"
    }
  }
];

  function validationError(message) {
    return { ok: false, code: 'validation_error', message: message };
  }

  function validateNumericBounds(path, schema, value) {
    if (schema.minimum != null && value < schema.minimum) {
      return validationError(path + ' must be at least ' + schema.minimum + '.');
    }
    if (schema.maximum != null && value > schema.maximum) {
      return validationError(path + ' must be at most ' + schema.maximum + '.');
    }
    return null;
  }

  function validateValue(path, schema, value) {
    var type = schema.type;
    if (!type) return null;
    switch (type) {
      case 'string':
        if (typeof value !== 'string') return validationError(path + ' must be a string.');
        return null;
      case 'integer':
        if (typeof value !== 'number' || value % 1 !== 0) {
          return validationError(path + ' must be an integer.');
        }
        return validateNumericBounds(path, schema, value);
      case 'number':
        if (typeof value !== 'number') return validationError(path + ' must be a number.');
        return validateNumericBounds(path, schema, value);
      case 'boolean':
        if (typeof value !== 'boolean') return validationError(path + ' must be a boolean.');
        return null;
      case 'object':
        if (typeof value !== 'object' || value === null || Array.isArray(value)) {
          return validationError(path + ' must be an object.');
        }
        return null;
      case 'array':
        if (!Array.isArray(value)) return validationError(path + ' must be an array.');
        var arrayPath = path;
        if (arrayPath.length >= 2 && arrayPath.charAt(0) === '"' &&
            arrayPath.charAt(arrayPath.length - 1) === '"') {
          arrayPath = arrayPath.slice(1, -1);
        }
        return validateArrayItems(arrayPath, schema, value);
      default:
        return null;
    }
  }

  function validateObjectProperties(pathPrefix, schema, args) {
    args = args && typeof args === 'object' && !Array.isArray(args) ? args : {};
    var properties = schema.properties || {};
    if (schema.additionalProperties === false) {
      for (var key in args) {
        if (Object.prototype.hasOwnProperty.call(args, key) &&
            !Object.prototype.hasOwnProperty.call(properties, key)) {
          var at = pathPrefix ? ' at "' + pathPrefix + '"' : '';
          return validationError('Unknown property "' + key + '"' + at + '.');
        }
      }
    }
    var required = schema.required;
    if (required && required.length) {
      for (var r = 0; r < required.length; r += 1) {
        var name = required[r];
        if (!Object.prototype.hasOwnProperty.call(args, name)) {
          var atReq = pathPrefix ? ' at "' + pathPrefix + '"' : '';
          return validationError('Missing required property "' + name + '"' + atReq + '.');
        }
      }
    }
    for (var prop in properties) {
      if (!Object.prototype.hasOwnProperty.call(properties, prop)) continue;
      if (!Object.prototype.hasOwnProperty.call(args, prop)) continue;
      var childPath = pathPrefix ? pathPrefix + '.' + prop : prop;
      var propErr = validateValue('"' + childPath + '"', properties[prop], args[prop]);
      if (propErr) return propErr;
    }
    return null;
  }

  function validateArrayItems(path, schema, value) {
    var items = schema.items;
    if (!items || typeof items !== 'object' || Array.isArray(items)) return null;
    if (items.type !== 'object') return null;
    var itemProperties = items.properties || {};
    var itemRequired = items.required;
    var hasRequired = itemRequired && itemRequired.length;
    var hasProps = false;
    for (var pk in itemProperties) {
      if (Object.prototype.hasOwnProperty.call(itemProperties, pk)) {
        hasProps = true;
        break;
      }
    }
    if (!hasProps && !hasRequired) return null;
    for (var i = 0; i < value.length; i += 1) {
      var element = value[i];
      var elementPath = path + '[' + i + ']';
      if (typeof element !== 'object' || element === null || Array.isArray(element)) {
        return validationError('"' + elementPath + '" must be an object.');
      }
      var objErr = validateObjectProperties(elementPath, items, element);
      if (objErr) return objErr;
    }
    return null;
  }

  function validateInput(schema, args) {
    if (!schema || schema.type !== 'object') return null;
    args = args && typeof args === 'object' && !Array.isArray(args) ? args : {};
    var properties = schema.properties || {};
    if (schema.additionalProperties === false) {
      for (var key in args) {
        if (Object.prototype.hasOwnProperty.call(args, key) &&
            !Object.prototype.hasOwnProperty.call(properties, key)) {
          return validationError('Unknown property "' + key + '".');
        }
      }
    }
    var required = schema.required;
    if (required && required.length) {
      for (var r = 0; r < required.length; r += 1) {
        var reqKey = required[r];
        if (!Object.prototype.hasOwnProperty.call(args, reqKey) ||
            args[reqKey] === undefined || args[reqKey] === null) {
          return validationError('Missing required property: ' + reqKey);
        }
      }
    }
    for (var prop in properties) {
      if (!Object.prototype.hasOwnProperty.call(properties, prop)) continue;
      if (!Object.prototype.hasOwnProperty.call(args, prop)) continue;
      var val = args[prop];
      if (val === undefined || val === null) continue;
      var propErr = validateValue('"' + prop + '"', properties[prop], val);
      if (propErr) return propErr;
    }
    return null;
  }

  function fetchInvoke(name, args) {
    return global.fetch(invokePath + '?name=' + encodeURIComponent(name), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(args || {}),
    }).then(function (response) {
      return response.json();
    });
  }

  tools.forEach(function (tool) {
    try {
      nav.modelContext.registerTool({
        name: tool.name,
        description: tool.description,
        inputSchema: tool.inputSchema,
        execute: function (args) {
          var err = validateInput(tool.inputSchema, args);
          if (err) return Promise.resolve(err);
          var dart = global.__agentkitWebMcpDartExecute;
          if (typeof dart === 'function') {
            return Promise.resolve(dart(tool.name, args || {})).then(function (result) {
              if (result != null) return result;
              return fetchInvoke(tool.name, args);
            });
          }
          return fetchInvoke(tool.name, args);
        },
      });
    } catch (e) {
      // Hot restart / Dart bootstrap may have registered the same name.
    }
  });
})(typeof globalThis !== 'undefined' ? globalThis : window);
''';
