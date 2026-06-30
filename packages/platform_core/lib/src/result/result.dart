import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';

@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.recoverableFailure(Exception exception, [StackTrace? stackTrace]) = RecoverableFailure<T>;
  const factory Result.fatalFailure(Exception exception, [StackTrace? stackTrace]) = FatalFailure<T>;
}
