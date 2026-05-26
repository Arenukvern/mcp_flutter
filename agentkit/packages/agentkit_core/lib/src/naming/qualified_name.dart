final _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');

void validateNamespace(final String namespace) {
  if (!_idPattern.hasMatch(namespace)) {
    throw ArgumentError('Invalid namespace: $namespace');
  }
}

void validateBareName(final String name) {
  if (!_idPattern.hasMatch(name)) {
    throw ArgumentError('Invalid name: $name');
  }
}

String qualifyName({required final String namespace, required final String name}) {
  validateNamespace(namespace);
  validateBareName(name);
  final prefix = '${namespace}_';
  if (name.startsWith(prefix)) {
    throw ArgumentError(
      'Bare name must not include namespace prefix: $name',
    );
  }
  return '${namespace}_$name';
}
