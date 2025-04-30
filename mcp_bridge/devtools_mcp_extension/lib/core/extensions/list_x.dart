// TODO(arenukvern): add to xsoulspace_foundation
extension AppListX<T> on List<T> {
  /// Upserts an element in the list based on a comparison function.
  /// If an element matching the comparison exists, it is replaced.
  /// Otherwise the new element is added to the end of the list.
  List<T> upsert(
    final T item,
    final bool Function(T e) predicate,
  ) {
    final index = indexWhere(predicate);
    if (index < 0) {
      return [...this, item];
    } else {
      return [...this]..[index] = item;
    }
  }
}
