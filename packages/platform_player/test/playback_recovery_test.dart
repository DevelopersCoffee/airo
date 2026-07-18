import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('AiroPlaybackDiagnosticMapper', () {
    const mapper = AiroPlaybackDiagnosticMapper();

    test('maps network timeout to a retryable network diagnostic', () {
      final diagnostic = mapper.map(
        const AiroPlaybackFailureEvent(
          engineError: AiroPlaybackError(
            code: AiroPlaybackErrorCode.networkUnavailable,
          ),
        ),
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.networkUnavailable);
      expect(diagnostic.severity, AiroPlaybackDiagnosticSeverity.recoverable);
      expect(diagnostic.retryEligible, isTrue);
    });

    test(
      'maps HTTP 401 and 403 to a non-retryable provider auth diagnostic',
      () {
        for (final status in [401, 403]) {
          final diagnostic = mapper.map(
            AiroPlaybackFailureEvent(httpStatusCode: status),
          );

          expect(
            diagnostic.code,
            AiroPlaybackDiagnosticCode.providerAuthDenied,
          );
          expect(diagnostic.retryEligible, isFalse);
        }
      },
    );

    test('maps HTTP 404 to a non-retryable provider not-found diagnostic', () {
      final diagnostic = mapper.map(
        const AiroPlaybackFailureEvent(httpStatusCode: 404),
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.providerNotFound);
      expect(diagnostic.retryEligible, isFalse);
    });

    test('maps HTTP 429 to a retryable rate-limit diagnostic', () {
      final diagnostic = mapper.map(
        const AiroPlaybackFailureEvent(httpStatusCode: 429),
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.providerRateLimited);
      expect(diagnostic.retryEligible, isTrue);
    });

    test('maps HTTP 5xx to a retryable provider server diagnostic', () {
      for (final status in [500, 502, 503]) {
        final diagnostic = mapper.map(
          AiroPlaybackFailureEvent(httpStatusCode: status),
        );

        expect(diagnostic.code, AiroPlaybackDiagnosticCode.providerServerError);
        expect(diagnostic.retryEligible, isTrue);
      }
    });

    test('maps unsupported codec to a fatal non-retryable diagnostic', () {
      final diagnostic = mapper.map(
        const AiroPlaybackFailureEvent(
          engineError: AiroPlaybackError(
            code: AiroPlaybackErrorCode.codecUnsupported,
          ),
        ),
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.codecUnsupported);
      expect(diagnostic.severity, AiroPlaybackDiagnosticSeverity.fatal);
      expect(diagnostic.retryEligible, isFalse);
    });

    test('maps buffer stall to a retryable stall diagnostic', () {
      final diagnostic = mapper.map(
        const AiroPlaybackFailureEvent(stalledFor: Duration(seconds: 6)),
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.streamStalled);
      expect(diagnostic.retryEligible, isTrue);
    });

    test('maps a short-run stop to a stable early-end diagnostic', () {
      final diagnostic = mapper.map(
        const AiroPlaybackFailureEvent(endedAfter: Duration(seconds: 20)),
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.streamEndedEarly);
      expect(diagnostic.retryEligible, isTrue);
    });

    test(
      'every diagnostic code has a stable id and non-empty user message',
      () {
        for (final code in AiroPlaybackDiagnosticCode.values) {
          expect(code.stableId, isNotEmpty);
          final diagnostic = mapper.map(
            AiroPlaybackFailureEvent(overrideCode: code),
          );
          expect(diagnostic.userMessage, isNotEmpty);
          expect(
            diagnostic.userMessage.length,
            lessThanOrEqualTo(80),
            reason: 'TV-safe copy must stay short for ${code.stableId}',
          );
        }
      },
    );

    test('redacts credentials and query strings from technical detail', () {
      final diagnostic = mapper.map(
        AiroPlaybackFailureEvent(
          httpStatusCode: 403,
          sourceUri: Uri.parse(
            'http://user:secret@provider.example.com:8080/live/user/pass/42.ts?token=abc123',
          ),
        ),
      );

      expect(diagnostic.technicalDetail, isNotNull);
      expect(diagnostic.technicalDetail, isNot(contains('secret')));
      expect(diagnostic.technicalDetail, isNot(contains('token=abc123')));
      expect(diagnostic.technicalDetail, isNot(contains('pass')));
    });
  });

  group('AiroPlaybackRetryPolicy', () {
    const policy = AiroPlaybackRetryPolicy();

    test('produces bounded exponential backoff delays', () {
      final delays = <Duration>[
        for (var attempt = 1; attempt <= policy.maxAttempts; attempt++)
          policy.delayForAttempt(attempt),
      ];

      for (var i = 1; i < delays.length; i++) {
        expect(
          delays[i] >= delays[i - 1],
          isTrue,
          reason: 'delays must not shrink',
        );
      }
      expect(delays.last, lessThanOrEqualTo(policy.maxDelay));
    });
  });

  group('AiroPlaybackRetryStateMachine', () {
    AiroPlaybackDiagnostic transient() => const AiroPlaybackDiagnosticMapper()
        .map(const AiroPlaybackFailureEvent(stalledFor: Duration(seconds: 6)));

    AiroPlaybackDiagnostic fatalAuth() => const AiroPlaybackDiagnosticMapper()
        .map(const AiroPlaybackFailureEvent(httpStatusCode: 401));

    test('retries a transient failure up to max attempts then stops', () {
      final machine = AiroPlaybackRetryStateMachine(
        policy: const AiroPlaybackRetryPolicy(maxAttempts: 3),
      );

      final decisions = <AiroPlaybackRetryDecision>[
        for (var i = 0; i < 3; i++) machine.onFailure(transient()),
      ];

      expect(
        decisions.map((d) => d.action),
        everyElement(AiroPlaybackRetryAction.retry),
      );
      expect(decisions.map((d) => d.attempt), [1, 2, 3]);

      final exhausted = machine.onFailure(transient());
      expect(exhausted.action, AiroPlaybackRetryAction.giveUp);
      expect(machine.isTerminal, isTrue);
    });

    test('does not retry non-retryable provider auth failures', () {
      final machine = AiroPlaybackRetryStateMachine();

      final decision = machine.onFailure(fatalAuth());

      expect(decision.action, AiroPlaybackRetryAction.stop);
      expect(machine.isTerminal, isTrue);
    });

    test('reset clears attempts for a new playback session', () {
      final machine = AiroPlaybackRetryStateMachine(
        policy: const AiroPlaybackRetryPolicy(maxAttempts: 1),
      );

      machine.onFailure(transient());
      machine.onFailure(transient());
      expect(machine.isTerminal, isTrue);

      machine.reset();

      expect(machine.isTerminal, isFalse);
      final decision = machine.onFailure(transient());
      expect(decision.action, AiroPlaybackRetryAction.retry);
      expect(decision.attempt, 1);
    });

    test('successful recovery resets the attempt counter', () {
      final machine = AiroPlaybackRetryStateMachine(
        policy: const AiroPlaybackRetryPolicy(maxAttempts: 2),
      );

      machine.onFailure(transient());
      machine.onPlaybackRecovered();

      final decision = machine.onFailure(transient());
      expect(decision.attempt, 1);
    });

    test('retry decisions carry the policy backoff delay', () {
      const policy = AiroPlaybackRetryPolicy(maxAttempts: 3);
      final machine = AiroPlaybackRetryStateMachine(policy: policy);

      final first = machine.onFailure(transient());
      final second = machine.onFailure(transient());

      expect(first.delay, policy.delayForAttempt(1));
      expect(second.delay, policy.delayForAttempt(2));
    });
  });
}
