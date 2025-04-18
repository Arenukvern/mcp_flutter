// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// An abstract implementation of a key value store.
///
/// We have concrete implementations for Flutter web, Flutter desktop, and
/// Flutter web when launched from the DevTools server.
abstract class Storage {
  /// Return the value associated with the given key.
  Future<String?> getValue(final String key);

  /// Set a value for the given key.
  Future<void> setValue(final String key, final String value);
}
