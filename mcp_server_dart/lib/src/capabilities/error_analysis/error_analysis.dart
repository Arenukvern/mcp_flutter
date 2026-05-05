// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

final class ErrorCauseAnalyzer {
  const ErrorCauseAnalyzer();

  List<Map<String, Object?>> analyze(final List<Map<String, Object?>> errors) {
    final causes = <Map<String, Object?>>[];

    for (final error in errors) {
      final text = _mergeErrorText(error);
      final lower = text.toLowerCase();

      if (lower.contains('renderflex overflowed by') ||
          lower.contains('a renderflex overflowed')) {
        final evidence = <String>[];
        final overflowLine = _extractFirstLineContaining(
          text,
          'RenderFlex overflowed',
        );
        if (overflowLine != null) {
          evidence.add(overflowLine);
        }
        final widgetLine = _extractWidgetLine(text);
        if (widgetLine != null) {
          evidence.add(widgetLine);
        }

        causes.add({
          'code': 'render_flex_overflow',
          'title': 'RenderFlex overflow in layout',
          'confidence': 0.95,
          'evidence': evidence,
          'remediation': const <String>[
            'Wrap overflowing child with Expanded/Flexible or constrain width.',
            'Use scrollable containers when content can exceed viewport size.',
            'Inspect the failing Row/Column at reported file:line and adjust layout constraints.',
          ],
        });
        continue;
      }

      if (lower.contains('null check operator used on a null value')) {
        causes.add({
          'code': 'null_check_on_null',
          'title': 'Null-check operator used on null value',
          'confidence': 0.9,
          'evidence': <String>[text.split('\n').first],
          'remediation': const <String>[
            'Guard nullable value before using ! operator.',
            'Trace nullable source and add defaults or early returns.',
          ],
        });
        continue;
      }

      if (lower.contains(
        'setstate() or markneedsbuild() called during build',
      )) {
        causes.add({
          'code': 'setstate_during_build',
          'title': 'State mutation during build phase',
          'confidence': 0.9,
          'evidence': <String>[text.split('\n').first],
          'remediation': const <String>[
            'Move state updates to callbacks/post-frame callbacks.',
            'Avoid mutating state synchronously while building widgets.',
          ],
        });
        continue;
      }

      causes.add({
        'code': 'unknown_runtime_error',
        'title': 'Unknown runtime error',
        'confidence': 0.35,
        'evidence': <String>[text.split('\n').first],
        'remediation': const <String>[
          'Inspect full stack trace and widget tree diagnostics.',
          'Collect view details and screenshots to correlate visual state.',
        ],
      });
    }

    final unique = <String>{};
    final deduped = <Map<String, Object?>>[];
    for (final cause in causes) {
      final key = '${cause['code']}:${cause['title']}';
      if (unique.add(key)) {
        deduped.add(cause);
      }
    }

    deduped.sort((final a, final b) {
      final ac = (a['confidence'] as num?)?.toDouble() ?? 0;
      final bc = (b['confidence'] as num?)?.toDouble() ?? 0;
      return bc.compareTo(ac);
    });

    return deduped;
  }

  String _mergeErrorText(final Map<String, Object?> error) {
    final candidates = <String>[];
    for (final key in const [
      'error',
      'message',
      'details',
      'stackTrace',
      'trace',
    ]) {
      final value = error[key];
      if (value == null) continue;
      if (value is String && value.trim().isNotEmpty) {
        candidates.add(value.trim());
      } else if (value is Map || value is List) {
        candidates.add('$value');
      }
    }

    if (candidates.isEmpty) {
      candidates.add('$error');
    }

    return candidates.join('\n');
  }

  String? _extractFirstLineContaining(final String text, final String needle) {
    for (final line in text.split('\n')) {
      if (line.contains(needle)) {
        return line.trim();
      }
    }
    return null;
  }

  String? _extractWidgetLine(final String text) {
    final lines = text.split('\n');

    for (final line in lines) {
      if (line.contains('file://') && RegExp(r':\d+:\d+').hasMatch(line)) {
        return line.trim();
      }
    }

    for (var i = 0; i < lines.length; i += 1) {
      final line = lines[i];
      if (line.contains('The relevant error-causing widget was:')) {
        for (var j = i + 1; j < lines.length; j += 1) {
          final candidate = lines[j].trim();
          if (candidate.isNotEmpty) {
            return candidate;
          }
        }
      }
    }

    return null;
  }
}
