@TestOn('vm')
library;

import 'package:test/test.dart';

import 'native_layer_evidence.dart';

void main() {
  test('accepts affirmative Impeller startup line only', () {
    final verdict = rendererVerdictFromLogs(
      [
        '[IMPORTANT:flutter/shell/platform/embedder/embedder_surface_gl_impeller.cc(126)] '
        'Using the Impeller rendering backend (OpenGLES).',
      ],
      platform: 'linux',
    );
    expect(verdict['rendererAccepted'], isTrue);
    expect(verdict['platformRendererAccepted'], isTrue);
    expect(verdict['activeRendererBackend'], 'impeller');
  });

  test('android requires Impeller affirmative startup', () {
    final verdict = rendererVerdictFromLogs(
      ['Using the Skia rendering backend.'],
      platform: 'android',
    );
    expect(verdict['rendererAccepted'], isTrue);
    expect(verdict['platformRendererAccepted'], isFalse);
  });

  test('rejects bare embedder filename without startup sentence', () {
    final verdict = rendererVerdictFromLogs(
      [
        'embedder_surface_gl_impeller.cc loaded',
      ],
      platform: 'linux',
    );
    expect(verdict['rendererAccepted'], isFalse);
    expect(verdict['honestGap'], isTrue);
    expect(verdict['activeRendererBackend'], 'unknown');
  });
}
