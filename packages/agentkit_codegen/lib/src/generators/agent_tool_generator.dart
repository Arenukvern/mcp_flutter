import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../agent_param.dart';
import '../agent_tool.dart';

/// Generates [RegisteredAgentIntent] / [AgentCallEntry] factories from
/// `@AgentTool` functions (Phase 5-C pilot).
class AgentToolGenerator extends GeneratorForAnnotation<AgentTool> {
  static final _agentParamChecker = TypeChecker.typeNamed(AgentParam);

  @override
  String generateForAnnotatedElement(
    final Element element,
    final ConstantReader annotation,
    final BuildStep buildStep,
  ) {
    if (element is! TopLevelFunctionElement) {
      throw InvalidGenerationSourceError(
        '@AgentTool can only annotate top-level functions.',
        element: element,
      );
    }

    final returnType = element.returnType;
    if (!_isAgentResultFuture(returnType)) {
      throw InvalidGenerationSourceError(
        '@AgentTool functions must return Future<AgentResult>.',
        element: element,
      );
    }

    final namespace = annotation.read('namespace').stringValue;
    final name = annotation.read('name').stringValue;
    final description = annotation.read('description').stringValue;

    final schemaName = '_${name}InputSchema';
    final registrationGetter = '${_toCamelCase(name)}Registration';
    final entryGetter = '${_toCamelCase(name)}CallEntry';

    final schema = _buildInputSchema(element);
    final handlerArgs = _buildHandlerArgs(element);

    return '''
const $schemaName = <String, Object?>$schema;

RegisteredAgentIntent get $registrationGetter =>
    $entryGetter.toRegistration();

AgentCallEntry get $entryGetter => AgentCallEntry.tool(
  namespace: ${_literalString(namespace)},
  name: ${_literalString(name)},
  description: ${_literalString(description)},
  inputSchema: $schemaName,
  handler: (final args) async => ${element.name}($handlerArgs),
);
''';
  }

  bool _isAgentResultFuture(final DartType type) {
    if (!type.isDartAsyncFuture) {
      return false;
    }
    final futureType = type as InterfaceType;
    if (futureType.typeArguments.isEmpty) {
      return false;
    }
    final inner = futureType.typeArguments.first;
    return inner.getDisplayString() == 'AgentResult';
  }

  String _buildInputSchema(final TopLevelFunctionElement element) {
    final properties = <String>[];
    final required = <String>[];

    for (final param in element.formalParameters) {
      final paramName = param.name;
      if (paramName == null) {
        continue;
      }

      final paramAnnotation = _readAgentParam(param);
      final description = paramAnnotation?.read('description').stringValue ??
          paramName;
      final isRequired =
          paramAnnotation?.read('required').boolValue ?? param.isRequired;

      final jsonType = _jsonTypeFor(param.type);
      properties.add('''
    ${_literalString(paramName)}: <String, Object?>{
      'type': ${_literalString(jsonType)},
      'description': ${_literalString(description)},
    },''');

      if (isRequired) {
        required.add(_literalString(paramName));
      }
    }

    return '''{
  'type': 'object',
  'properties': <String, Object?>{
${properties.join('\n')}
  },
  'required': <String>[${required.join(', ')}],
}''';
  }

  String _buildHandlerArgs(final TopLevelFunctionElement element) {
    return element.formalParameters.map((final param) {
      final name = param.name;
      if (name == null) {
        return '';
      }
      return 'args[${_literalString(name)}] as ${_dartTypeName(param.type)}';
    }).join(', ');
  }

  ConstantReader? _readAgentParam(final FormalParameterElement param) {
    for (final meta in param.metadata.annotations) {
      final value = ConstantReader(meta.computeConstantValue());
      if (value.instanceOf(_agentParamChecker)) {
        return value;
      }
    }
    return null;
  }

  String _jsonTypeFor(final DartType type) {
    if (type.isDartCoreInt) {
      return 'integer';
    }
    if (type.isDartCoreBool) {
      return 'boolean';
    }
    if (type.isDartCoreDouble) {
      return 'number';
    }
    return 'string';
  }

  String _dartTypeName(final DartType type) {
    if (type.isDartCoreInt) {
      return 'int';
    }
    if (type.isDartCoreBool) {
      return 'bool';
    }
    if (type.isDartCoreDouble) {
      return 'double';
    }
    return 'String';
  }

  String _literalString(final String value) =>
      "'${value.replaceAll("'", r"\'")}'";

  String _toCamelCase(final String value) {
    if (value.isEmpty) {
      return value;
    }
    final parts = value.split('_');
    final first = parts.first;
    final rest = parts.skip(1).map((final part) {
      if (part.isEmpty) {
        return part;
      }
      return part[0].toUpperCase() + part.substring(1);
    });
    return first + rest.join();
  }
}
