// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
import 'dart:math' as math;

// TODO(jacobr): move more math utils over to this library.

double sum(final Iterable<double> numbers) =>
    numbers.fold(0, (final sum, final cur) => sum + cur);

double min(final Iterable<double> numbers) =>
    numbers.fold(double.infinity, math.min);

double max(final Iterable<double> numbers) =>
    numbers.fold(-double.infinity, math.max);
