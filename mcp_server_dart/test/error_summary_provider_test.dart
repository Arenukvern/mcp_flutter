import 'package:flutter_inspector_mcp_server/src/capabilities/ai_providers/error_summary_provider.dart';
import 'package:test/test.dart';

void main() {
  group('resolveExplainErrorsSummary', () {
    test('skipped when includeSummary is false', () async {
      final o = await resolveExplainErrorsSummary(
        includeSummary: false,
        allowExternalSummary: false,
        provider: const NoopErrorSummaryProvider(),
        summarize: () async => throw StateError('must not call'),
      );
      expect(o.status, ErrorSummaryStatus.skipped);
      expect(o.reasonCode, equals('not_requested'));
    });

    test('skipped when external consent missing for OpenAI', () async {
      final o = await resolveExplainErrorsSummary(
        includeSummary: true,
        allowExternalSummary: false,
        provider: OpenAiErrorSummaryProvider(apiKey: 'sk-test'),
        summarize: () async => throw StateError('must not call'),
      );
      expect(o.status, ErrorSummaryStatus.skipped);
      expect(o.reasonCode, equals('external_consent_required'));
      expect(o.safeDetail, contains('allowExternalSummary'));
    });

    test('maps unexpected throw to failed unexpected', () async {
      final o = await resolveExplainErrorsSummary(
        includeSummary: true,
        allowExternalSummary: true,
        provider: OpenAiErrorSummaryProvider(apiKey: 'sk-test'),
        summarize: () async => throw StateError('boom'),
      );
      expect(o.status, ErrorSummaryStatus.failed);
      expect(o.reasonCode, equals('unexpected'));
      expect(o.safeDetail, contains('boom'));
    });

    test('invokes summarize when noop provider and includeSummary', () async {
      final o = await resolveExplainErrorsSummary(
        includeSummary: true,
        allowExternalSummary: false,
        provider: const NoopErrorSummaryProvider(),
        summarize: () => const NoopErrorSummaryProvider().summarize(
          errors: const <Map<String, Object?>>[],
          causes: const <Map<String, Object?>>[],
        ),
      );
      expect(o.status, ErrorSummaryStatus.skipped);
      expect(o.reasonCode, equals('provider_none'));
    });
  });

  group('OpenAiErrorSummaryProvider', () {
    test('empty api key returns failed no_api_key without throwing', () async {
      final p = OpenAiErrorSummaryProvider(apiKey: '');
      final o = await p.summarize(
        errors: const <Map<String, Object?>>[
          <String, Object?>{'message': 'x'},
        ],
        causes: const <Map<String, Object?>>[],
      );
      expect(o.status, ErrorSummaryStatus.failed);
      expect(o.reasonCode, equals('no_api_key'));
    });

    test('requiresExternalConsent is true', () {
      expect(OpenAiErrorSummaryProvider().requiresExternalConsent, isTrue);
    });
  });

  group('NoopErrorSummaryProvider', () {
    test('requiresExternalConsent is false', () {
      expect(const NoopErrorSummaryProvider().requiresExternalConsent, isFalse);
    });
  });
}
