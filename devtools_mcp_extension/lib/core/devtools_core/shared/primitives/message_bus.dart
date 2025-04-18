// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:meta/meta.dart';

/// An event type for use with [MessageBus].
class BusEvent {
  BusEvent(this.type, {this.data});

  final String type;
  final Object? data;

  @override
  String toString() => type;
}

/// A message bus class. Clients can listen for classes of events, optionally
/// filtered by a string type. This can be used to decouple events sources and
/// event listeners.
class MessageBus {
  MessageBus() {
    _controller = StreamController<BusEvent>.broadcast();
  }

  late StreamController<BusEvent> _controller;

  /// Listen for events on the event bus. Clients can pass in an optional [type],
  /// which filters the events to only those specific ones.
  Stream<BusEvent> onEvent({final String? type}) => type == null
        ? _controller.stream
        : _controller.stream.where((final event) => event.type == type);

  /// Add an event to the event bus.
  void addEvent(final BusEvent event) {
    _controller.add(event);
  }

  /// Close (destroy) this [MessageBus]. This is generally not used outside of a
  /// testing context. All stream listeners will be closed and the bus will not
  /// fire any more events.
  @visibleForTesting
  void close() {
    unawaited(_controller.close());
  }
}
