import 'package:flutter_test/flutter_test.dart';
import 'package:core_domain/core_domain.dart';

void main() {
  group('Result', () {
    test('Ok contains value', () {
      final result = Ok(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.getOrNull(), 42);
    });

    test('Err contains error', () {
      final result = Err<int>('error', StackTrace.current);
      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.getOrNull(), isNull);
      expect(result.getErrorOrNull(), 'error');
    });

    test('map transforms Ok value', () {
      final result = Ok(10);
      final mapped = result.map((v) => v * 2);
      expect(mapped.getOrNull(), 20);
    });

    test('map preserves Err', () {
      final result = Err<int>('error', StackTrace.current);
      final mapped = result.map((v) => v * 2);
      expect(mapped.isErr, isTrue);
    });

    test('flatMap chains operations', () {
      final result = Ok(10);
      final chained = result.flatMap((v) => Ok(v.toString()));
      expect(chained.getOrNull(), '10');
    });

    test('fold handles both cases', () {
      final ok = Ok(42);
      final err = Err<int>('error', StackTrace.current);

      expect(ok.fold((e, s) => 'error', (v) => 'value: $v'), 'value: 42');
      expect(err.fold((e, s) => 'error: $e', (v) => 'value'), 'error: error');
    });

    test('toOk extension creates Ok result', () {
      final result = 42.toOk();
      expect(result.isOk, isTrue);
      expect(result.getOrNull(), 42);
    });
  });

  group('AppError', () {
    test('AppError has code and message', () {
      final error = AppError('TEST_ERROR', 'Test message');
      expect(error.code, 'TEST_ERROR');
      expect(error.message, 'Test message');
    });

    test('NetworkError has correct code', () {
      final error = NetworkError('Connection failed');
      expect(error.code, 'NETWORK_ERROR');
    });

    test('AuthenticationError has correct code and default status', () {
      final error = AuthenticationError('Unauthorized');
      expect(error.code, 'AUTH_ERROR');
      expect(error.statusCode, 401);
    });

    test('ValidationError can have field errors', () {
      final error = ValidationError(
        'Invalid input',
        fieldErrors: {'email': 'Invalid email format'},
      );
      expect(error.code, 'VALIDATION_ERROR');
      expect(error.fieldErrors['email'], 'Invalid email format');
    });

    test('NotFoundError has correct status code', () {
      final error = NotFoundError('Resource not found');
      expect(error.statusCode, 404);
    });

    test('AIError has correct code', () {
      final error = AIError('Model unavailable');
      expect(error.code, 'AI_ERROR');
    });
  });

  group('AsyncState', () {
    test('initial creates AsyncInitial', () {
      final state = AsyncState<int>.initial();
      expect(state.isInitial, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.hasData, isFalse);
      expect(state.hasError, isFalse);
    });

    test('loading creates AsyncLoading', () {
      final state = AsyncState<int>.loading();
      expect(state.isLoading, isTrue);
      expect(state.dataOrNull, isNull);
    });

    test('loading with previousData preserves data', () {
      final state = AsyncState<int>.loading(previousData: 42);
      expect(state.isLoading, isTrue);
      expect(state.dataOrNull, 42);
    });

    test('data creates AsyncData', () {
      final state = AsyncState<int>.data(42);
      expect(state.hasData, isTrue);
      expect(state.dataOrNull, 42);
    });

    test('error creates AsyncError', () {
      final state = AsyncState<int>.error('Something went wrong');
      expect(state.hasError, isTrue);
      expect(state.errorOrNull, 'Something went wrong');
    });

    test('error with previousData preserves data', () {
      final state = AsyncState<int>.error('Error', previousData: 42);
      expect(state.hasError, isTrue);
      expect(state.dataOrNull, 42);
    });

    test('map transforms data', () {
      final state = AsyncState<int>.data(10);
      final mapped = state.map((v) => v * 2);
      expect(mapped.dataOrNull, 20);
    });

    test('when handles all cases', () {
      final initial = AsyncState<int>.initial();
      final loading = AsyncState<int>.loading();
      final data = AsyncState<int>.data(42);
      final error = AsyncState<int>.error('Error');

      expect(
        initial.when(
          initial: () => 'initial',
          loading: (_) => 'loading',
          data: (d) => 'data: $d',
          error: (e, s, d) => 'error: $e',
        ),
        'initial',
      );

      expect(
        loading.when(
          initial: () => 'initial',
          loading: (_) => 'loading',
          data: (d) => 'data: $d',
          error: (e, s, d) => 'error: $e',
        ),
        'loading',
      );

      expect(
        data.when(
          initial: () => 'initial',
          loading: (_) => 'loading',
          data: (d) => 'data: $d',
          error: (e, s, d) => 'error: $e',
        ),
        'data: 42',
      );

      expect(
        error.when(
          initial: () => 'initial',
          loading: (_) => 'loading',
          data: (d) => 'data: $d',
          error: (e, s, d) => 'error: $e',
        ),
        'error: Error',
      );
    });
  });

  group('PaginatedState', () {
    test('initial creates empty state', () {
      final state = PaginatedState<String>.initial();
      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.page, 0);
    });

    test('loading creates loading state', () {
      final state = PaginatedState<String>.loading();
      expect(state.isLoading, isTrue);
    });

    test('setData sets first page data', () {
      var state = PaginatedState<String>.loading();
      state = state.setData(['a', 'b', 'c'], hasMore: true);
      expect(state.items, ['a', 'b', 'c']);
      expect(state.isLoading, isFalse);
      expect(state.page, 1);
      expect(state.hasMore, isTrue);
    });

    test('appendData adds more items', () {
      var state = PaginatedState<String>.initial();
      state = state.setData(['a', 'b']);
      state = state.appendData(['c', 'd'], hasMore: false);
      expect(state.items, ['a', 'b', 'c', 'd']);
      expect(state.page, 2);
      expect(state.hasMore, isFalse);
    });

    test('prependItem adds to beginning', () {
      var state = PaginatedState<String>.initial();
      state = state.setData(['b', 'c']);
      state = state.prependItem('a');
      expect(state.items, ['a', 'b', 'c']);
    });

    test('removeWhere removes matching items', () {
      var state = PaginatedState<String>.initial();
      state = state.setData(['a', 'b', 'c']);
      state = state.removeWhere((item) => item == 'b');
      expect(state.items, ['a', 'c']);
    });

    test('updateWhere updates matching items', () {
      var state = PaginatedState<String>.initial();
      state = state.setData(['a', 'b', 'c']);
      state = state.updateWhere((item) => item == 'b', (item) => 'B');
      expect(state.items, ['a', 'B', 'c']);
    });

    test('setError sets error state', () {
      var state = PaginatedState<String>.loading();
      state = state.setError('Network error');
      expect(state.hasError, isTrue);
      expect(state.error, 'Network error');
      expect(state.isLoading, isFalse);
    });
  });
}
