// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

mixin EnumIndexOrdering<T extends Enum> on Enum implements Comparable<T> {
  @override
  int compareTo(final T other) => index.compareTo(other.index);

  bool operator <(final T other) => index < other.index;

  bool operator >(final T other) => index > other.index;

  bool operator >=(final T other) => index >= other.index;

  bool operator <=(final T other) => index <= other.index;
}
