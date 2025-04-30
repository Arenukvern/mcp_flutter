// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:collection';
import 'dart:math';

/// Non-UI specific tree code should live in this file.
///
/// This file does not have direct dependencies on dart:html and therefore
/// allows for testing to be done on the VM.

// TODO(kenz): look into consolidating logic between this file and
// ui/trees.dart, which houses generic tree types vs the base classes in this
// file.

abstract class TreeNode<T extends TreeNode<T>> {
  T? parent;

  final children = <T>[];

  // TODO(jacobr) should impact depth.
  bool indentChildren = true;

  /// Index in `parent.children`.
  int index = -1;

  /// Depth of this tree, including `this`.
  ///
  /// We assume that TreeNodes are not modified after the first time [depth] is
  /// accessed. We would need to clear the cache before accessing, otherwise.
  int get depth {
    if (_depth != 0) {
      return _depth;
    }
    for (final child in children) {
      _depth = max(_depth, child.depth);
    }
    return _depth = _depth + 1;
  }

  var _depth = 0;

  bool get isRoot => parent == null;

  bool get isSelected => _selected;
  var _selected = false;

  T get root {
    if (_root != null) {
      return _root!;
    }
    if (parent == null) return _root = this as T;
    return _root = parent!.root;
  }

  T? _root;

  /// The level (0-based) of this tree node in the tree.
  int get level {
    if (_level != null) {
      return _level!;
    }
    if (parent == null) return _level = 0;
    return _level = 1 + parent!.level;
  }

  int? _level;

  /// Whether the tree table node is expandable.
  bool get isExpandable => children.isNotEmpty;

  /// Whether the node is currently expanded in the tree table.
  bool get isExpanded => _isExpanded;
  var _isExpanded = false;

  // TODO(gmoothart): expand does not check isExpandable, which can lead to
  // inconsistent state, particular in combination with expandCascading. We
  // should clean this up.
  void expand() {
    _isExpanded = true;
  }

  void select() {
    _selected = true;
  }

  void unselect() {
    _selected = false;
  }

  // TODO(jacobr): cache the value of whether the node should be shown
  // so that lookups on this class are O(1) invalidating the cache when nodes
  // up the tree are expanded and collapsed.
  /// Whether this node should be shown in the tree.
  ///
  /// When using this, consider caching the value. It is O([level]) to compute.
  bool shouldShow() =>
      parent == null || (parent!.isExpanded && parent!.shouldShow());

  void collapse() {
    _isExpanded = false;
  }

  void toggleExpansion() {
    _isExpanded = !_isExpanded;
  }

  /// Override to handle pressing on a Leaf node.
  void leaf() {}

  void addChild(final T child, {int? index}) {
    index ??= children.length;
    assert(index <= children.length);
    children.insert(index, child);
    child.parent = this as T?;
    child.index = index;
    for (int i = index + 1; i < children.length; ++i) {
      children[i].index++;
    }
  }

  T removeChildAtIndex(final int index) {
    assert(index < children.length);
    for (int i = index + 1; i < children.length; ++i) {
      children[i].index--;
    }
    return children.removeAt(index);
  }

  void addAllChildren(final List<T> children) {
    children.forEach(addChild);
  }

  /// Expands this node and all of its children (cascading).
  void expandCascading() {
    breadthFirstTraversal<T>(
      this as T,
      action: (final node) {
        node.expand();
      },
    );
  }

  /// Expands this node and each parent node recursively.
  void expandAscending() {
    expand();
    parent?.expandAscending();
  }

  /// Collapses this node and all of its children (cascading).
  void collapseCascading() {
    breadthFirstTraversal<T>(
      this as T,
      action: (final node) {
        node.collapse();
      },
    );
  }

  bool subtreeHasNodeWithCondition(final bool Function(T node) condition) {
    final T? childWithCondition = firstChildWithCondition(condition);
    return childWithCondition != null;
  }

  /// Returns a list of nodes in this tree that match [condition].
  ///
  /// This list may include the root.
  List<T> nodesWithCondition(final bool Function(T node) condition) {
    final nodes = <T>[];
    breadthFirstTraversal<T>(
      this as T,
      action: (final node) {
        if (condition(node)) {
          nodes.add(node);
        }
      },
    );
    return nodes;
  }

  /// Returns a list of shallow nodes that match [condition], meaning that if
  /// a node matches [condition], none of its children will be included in the
  /// returned list, even if those children happen to match [condition].
  ///
  /// In other words, only the top-most node in each tree branch that matches
  /// [condition] will be included in the returned list. This list may include
  /// the root.
  List<T> shallowNodesWithCondition(final bool Function(T node) condition) {
    final nodes = <T>[];
    depthFirstTraversal<T>(
      this as T,
      action: (final node) {
        if (condition(node)) {
          nodes.add(node);
        }
      },
      exploreChildrenCondition: (final node) => !condition(node),
    );
    return nodes;
  }

  T? firstChildWithCondition(final bool Function(T node) condition) =>
      breadthFirstTraversal<T>(this as T, returnCondition: condition);

  /// Locates the first sub-node in the tree at level [level].
  ///
  /// [level] is relative to the subtree root `this`.
  ///
  /// For example:
  ///
  /// [level 0]                A
  ///                        /   \
  /// [level 1]             B     E
  ///                      /    /  \
  /// [level 2]           C    F    G
  ///                    /
  /// [level 3]         D
  ///
  /// E.firstSubNodeAtLevel(1) => F
  T? firstChildNodeAtLevel(final int level) => _childNodeAtLevelWithCondition(
    level,
    // When this condition is called, we have already ensured that
    // [level] < [depth], so at least one child is guaranteed to meet the
    // firstWhere condition.
    (final currentNode, final levelWithOffset) => currentNode.children
        .firstWhere((final n) => n.depth + n.level > levelWithOffset),
  );

  /// Locates the last sub-node in the tree at level [level].
  ///
  /// [level] is relative to the subtree root `this`.
  ///
  /// For example:
  ///
  /// [level 0]                A
  ///                        /   \
  /// [level 1]             B     E
  ///                      /    /  \
  /// [level 2]           C    F    G
  ///                    /
  /// [level 3]         D
  ///
  /// E.lastSubNodeAtLevel(1) => G
  T? lastChildNodeAtLevel(final int level) => _childNodeAtLevelWithCondition(
    level,
    // When this condition is called, we have already ensured that
    // [level] < [depth], so at least one child is guaranteed to meet the
    // lastWhere condition.
    (final currentNode, final levelWithOffset) => currentNode.children
        .lastWhere((final n) => n.depth + n.level > levelWithOffset),
  );

  // TODO(kenz): We should audit this method with a very large tree:
  // https://github.com/flutter/devtools/issues/1480.
  /// Finds a child node at [level] where traversal order is determined by
  /// [traversalCondition].
  ///
  /// The runtime of this method is O(level * tree width). The worst case
  /// scenario is searching for a very deep level in a very wide tree.
  T? _childNodeAtLevelWithCondition(
    final int level,
    final T Function(T currentNode, int levelWithOffset) traversalCondition,
  ) {
    if (level >= depth) return null;
    // The current node [this] is not guaranteed to be at level 0, so we need
    // to account for the level offset of [this].
    final levelWithOffset = level + this.level;
    TreeNode<T> currentNode = this;
    while (currentNode.level < levelWithOffset) {
      // Walk down the tree until we find the node at [level].
      if (currentNode.children.isNotEmpty) {
        currentNode = traversalCondition(currentNode as T, levelWithOffset);
      }
    }
    return currentNode as T?;
  }

  TreeNode<T> shallowCopy();

  /// Filters a tree starting at this node and returns a list of new roots after
  /// filtering, where all nodes in the new tree(s) meet the condition `filter`.
  ///
  /// If the root `this` should be included in the filtered results, the list
  /// will contain one node. If the root `this` should not be included in the
  /// filtered results, the list may contain one or more nodes.
  List<T> filterWhere(final bool Function(T node) filter) {
    List<T> walkAndCopy(final T node) {
      if (filter(node)) {
        final copy = node.shallowCopy();
        for (final child in node.children) {
          copy.addAllChildren(walkAndCopy(child));
        }
        return [copy as T];
      }
      return [for (final child in node.children) ...walkAndCopy(child)];
    }

    return walkAndCopy(this as T);
  }

  int childCountToMatchingNode({
    final bool Function(T node)? matchingNodeCondition,
    final bool includeCollapsedNodes = true,
  }) {
    var index = 0;
    final matchingNode = depthFirstTraversal<T>(
      root,
      returnCondition: matchingNodeCondition,
      exploreChildrenCondition:
          includeCollapsedNodes ? null : (final node) => node.isExpanded,
      action: (_) => index++,
    );
    if (matchingNode != null) return index;
    return -1;
  }
}

/// Traverses a tree in breadth-first order.
///
/// [returnCondition] specifies the condition for which we should stop
/// traversing the tree. For example, if we are calling this method to perform
/// BFS, [returnCondition] would specify when we have found the node we are
/// searching for. [action] specifies an action that we will execute on each
/// node. For example, if we need to traverse a tree and change a property on
/// every single node, we would do this through the [action] param.
T? breadthFirstTraversal<T extends TreeNode<T>>(
  final T root, {
  final bool Function(T node)? returnCondition,
  final void Function(T node)? action,
}) => _treeTraversal(root, returnCondition: returnCondition, action: action);

/// Traverses a tree in depth-first preorder order.
///
/// [returnCondition] specifies the condition for which we should stop
/// traversing the tree. For example, if we are calling this method to perform
/// DFS, [returnCondition] would specify when we have found the node we are
/// searching for. [action] specifies an action that we will execute on each
/// node. For example, if we need to traverse a tree and change a property on
/// every single node, we would do this through the [action] param.
/// [exploreChildrenCondition] specifies the condition for which we should
/// explore the children of a node. By default, all children are explored.
T? depthFirstTraversal<T extends TreeNode<T>>(
  final T root, {
  final bool Function(T node)? returnCondition,
  final void Function(T node)? action,
  final bool Function(T node)? exploreChildrenCondition,
}) => _treeTraversal(
  root,
  bfs: false,
  returnCondition: returnCondition,
  action: action,
  exploreChildrenCondition: exploreChildrenCondition,
);

T? _treeTraversal<T extends TreeNode<T>>(
  final T root, {
  final bool bfs = true,
  final bool Function(T node)? returnCondition,
  final void Function(T node)? action,
  final bool Function(T node)? exploreChildrenCondition,
}) {
  final toVisit = Queue.of([root]);
  while (toVisit.isNotEmpty) {
    final node = bfs ? toVisit.removeFirst() : toVisit.removeLast();
    if (returnCondition != null && returnCondition(node)) {
      return node;
    }
    if (action != null) {
      action(node);
    }
    if (exploreChildrenCondition == null || exploreChildrenCondition(node)) {
      // For DFS, reverse the children to guarantee preorder traversal.
      final children = bfs ? node.children : node.children.reversed;
      children.forEach(toVisit.add);
    }
  }
  return null;
}

List<T> buildFlatList<T extends TreeNode<T>>(
  final List<T> roots, {
  final void Function(T node)? onTraverse,
}) {
  final flatList = <T>[];
  for (final root in roots) {
    _traverse(root, (final n) {
      if (onTraverse != null) onTraverse(n);
      flatList.add(n);
      return n.isExpanded;
    });
  }
  return flatList;
}

void _traverse<T extends TreeNode<T>>(
  final T node,
  final bool Function(T) callback,
) {
  final shouldContinue = callback(node);
  if (shouldContinue) {
    for (final child in node.children) {
      _traverse(child, callback);
    }
  }
}
