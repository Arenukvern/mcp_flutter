/// Per-isolate cache of optional toolkit verbs confirmed absent after grace.
final class ToolkitOptionalAbsentCache {
  final Map<String, Set<String>> _byIsolate = {};

  bool isAbsent(String? isolateId, String extension) {
    if (isolateId == null) return false;
    return _byIsolate[isolateId]?.contains(extension) ?? false;
  }

  void markAbsent(String? isolateId, String extension) {
    if (isolateId == null) return;
    _byIsolate.putIfAbsent(isolateId, () => {}).add(extension);
  }

  /// Clears cached absences for [isolateId] (e.g. after a hot restart).
  void clearIsolate(String? isolateId) {
    if (isolateId == null) return;
    _byIsolate.remove(isolateId);
  }

  void onIsolateChanged(String? previousId, String? newId) {
    if (previousId == newId) return;
    if (previousId != null) clearIsolate(previousId);
    if (newId != null) clearIsolate(newId);
  }
}
