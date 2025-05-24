// ignore_for_file: avoid_catches_without_on_clauses

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:vm_service/vm_service.dart';

class ObjectGroup {
  ObjectGroup({
    required this.debugName,
    required this.vmService,
    required this.isolate,
  }) : groupName = const Uuid().v4();

  final String debugName;
  final VmService vmService;
  final ValueListenable<IsolateRef?> isolate;
  final String groupName;
  var _disposed = false;

  bool get disposed => _disposed;

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    try {
      await vmService.callServiceExtension(
        'ext.flutter.inspector.disposeGroup',
        isolateId: isolate.value?.id,
        args: {'groupName': groupName},
      );
    } catch (e, stackTrace) {
      // Log the error, but don't rethrow.
      print('Error disposing object group $groupName: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _disposed = true;
    }
  }
}

class ObjectGroupManager {
  ObjectGroupManager({
    required this.debugName,
    required this.vmService,
    required this.isolate,
  });

  final String debugName;
  final VmService vmService;
  final ValueListenable<IsolateRef?> isolate;

  ObjectGroup? _current;
  ObjectGroup? _next;

  ObjectGroup get next {
    if (_next != null) {
      // If _next was previously disposed, create a new one.
      if (_next!.disposed) {
        _next = ObjectGroup(
          debugName: debugName,
          vmService: vmService,
          isolate: isolate,
        );
      }
      return _next!;
    }
    _next = ObjectGroup(
      debugName: debugName,
      vmService: vmService,
      isolate: isolate,
    );
    return _next!;
  }

  Future<void> promoteNext() async {
    await _current?.dispose();
    _current = _next;
    _next = null;
  }

  Future<void> cancelNext() async {
    await _next?.dispose();
    _next = null;
  }

  Future<void> dispose() async {
    await _current?.dispose();
    await _next?.dispose();
    _current = null;
    _next = null;
  }
}
