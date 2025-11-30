import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    group('Success', () {
      test('isSuccess returns true', () {
        const result = Success(42);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('value returns the contained value', () {
        const result = Success('hello');
        expect(result.value, 'hello');
      });

      test('valueOrNull returns the value', () {
        const result = Success(42);
        expect(result.valueOrNull, 42);
      });

      test('failure throws StateError', () {
        const result = Success(42);
        expect(() => result.failure, throwsStateError);
      });
    });

    group('Failure', () {
      test('isFailure returns true', () {
        const result = Failure<int>(ServerFailure());
        expect(result.isFailure, isTrue);
        expect(result.isSuccess, isFalse);
      });

      test('failure returns the contained failure', () {
        const failure = ServerFailure(message: 'Error');
        const result = Failure<int>(failure);
        expect(result.failure, failure);
      });

      test('valueOrNull returns null', () {
        const result = Failure<int>(ServerFailure());
        expect(result.valueOrNull, isNull);
      });

      test('value throws StateError', () {
        const result = Failure<int>(ServerFailure());
        expect(() => result.value, throwsStateError);
      });
    });

    group('map', () {
      test('transforms success value', () {
        const result = Success(10);
        final mapped = result.map((v) => v * 2);

        expect(mapped.isSuccess, isTrue);
        expect(mapped.value, 20);
      });

      test('preserves failure', () {
        const failure = ServerFailure(message: 'Error');
        const result = Failure<int>(failure);
        final mapped = result.map((v) => v * 2);

        expect(mapped.isFailure, isTrue);
        expect(mapped.failure, failure);
      });
    });

    group('flatMap', () {
      test('chains successful operations', () {
        const result = Success(10);
        final chained = result.flatMap((v) => Success(v * 2));

        expect(chained.isSuccess, isTrue);
        expect(chained.value, 20);
      });

      test('propagates failure from original', () {
        const failure = ServerFailure();
        const result = Failure<int>(failure);
        final chained = result.flatMap((v) => Success(v * 2));

        expect(chained.isFailure, isTrue);
      });

      test('propagates failure from mapped function', () {
        const result = Success(10);
        const failure = ValidationFailure(message: 'Invalid');
        final chained = result.flatMap<int>((v) => Failure(failure));

        expect(chained.isFailure, isTrue);
        expect(chained.failure, failure);
      });
    });

    group('fold', () {
      test('calls onSuccess for success', () {
        const result = Success(10);
        final value = result.fold(
          onSuccess: (v) => 'Success: $v',
          onFailure: (f) => 'Failure: ${f.message}',
        );

        expect(value, 'Success: 10');
      });

      test('calls onFailure for failure', () {
        const result = Failure<int>(ServerFailure(message: 'Error'));
        final value = result.fold(
          onSuccess: (v) => 'Success: $v',
          onFailure: (f) => 'Failure: ${f.message}',
        );

        expect(value, 'Failure: Error');
      });
    });

    group('onSuccess', () {
      test('executes action for success', () {
        var executed = false;
        const result = Success(10);
        result.onSuccess((v) => executed = true);

        expect(executed, isTrue);
      });

      test('does not execute action for failure', () {
        var executed = false;
        const result = Failure<int>(ServerFailure());
        result.onSuccess((v) => executed = true);

        expect(executed, isFalse);
      });
    });

    group('onFailure', () {
      test('executes action for failure', () {
        var executed = false;
        const result = Failure<int>(ServerFailure());
        result.onFailure((f) => executed = true);

        expect(executed, isTrue);
      });

      test('does not execute action for success', () {
        var executed = false;
        const result = Success(10);
        result.onFailure((f) => executed = true);

        expect(executed, isFalse);
      });
    });
  });
}

