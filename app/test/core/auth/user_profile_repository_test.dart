import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airo_app/core/auth/models/user_profile.dart';
import 'package:airo_app/core/auth/repositories/user_profile_repository.dart';
import 'package:airo_app/core/utils/locale_settings.dart';

void main() {
  late LocalUserProfileRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalUserProfileRepository();
  });

  group('LocalUserProfileRepository', () {
    group('saveProfile and getCurrentProfile', () {
      test('should save and retrieve profile correctly', () async {
        final profile = UserProfile.withDefaults(
          id: 'user123',
          username: 'testuser',
          displayName: 'Test User',
          email: 'test@example.com',
        );

        final saveResult = await repository.saveProfile(profile);
        final getResult = await repository.getCurrentProfile();

        expect(saveResult.isOk, true);
        expect(getResult.isOk, true);

        final retrieved = getResult.getOrNull();
        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'user123');
        expect(retrieved.username, 'testuser');
        expect(retrieved.displayName, 'Test User');
        expect(retrieved.email, 'test@example.com');
      });

      test('should have Indian locale settings by default', () async {
        final profile = UserProfile.withDefaults(
          id: 'user123',
          username: 'indianuser',
        );

        await repository.saveProfile(profile);
        final result = await repository.getCurrentProfile();

        final retrieved = result.getOrNull();
        expect(retrieved, isNotNull);
        expect(retrieved!.localeSettings.locale, 'en_IN');
        expect(retrieved.localeSettings.currency, 'INR');
        expect(retrieved.localeSettings.dateFormat, 'dd/MM/yyyy');
      });
    });

    group('updateProfile', () {
      test('should update profile fields correctly', () async {
        final profile = UserProfile.withDefaults(
          id: 'user123',
          username: 'testuser',
        );
        await repository.saveProfile(profile);

        final result = await repository.updateProfile(
          displayName: 'Updated Name',
          email: 'updated@example.com',
        );

        expect(result.isOk, true);
        final updated = result.getOrNull();
        expect(updated!.displayName, 'Updated Name');
        expect(updated.email, 'updated@example.com');
        expect(updated.username, 'testuser');
      });

      test('should update locale settings correctly', () async {
        final profile = UserProfile.withDefaults(
          id: 'user123',
          username: 'testuser',
        );
        await repository.saveProfile(profile);

        final result = await repository.updateProfile(
          localeSettings: LocaleSettings.us,
        );

        expect(result.isOk, true);
        final updated = result.getOrNull();
        expect(updated!.localeSettings.currency, 'USD');
        expect(updated.localeSettings.locale, 'en_US');
      });

      test('should return error when no profile exists', () async {
        final result = await repository.updateProfile(
          displayName: 'New Name',
        );

        expect(result.isErr, true);
      });
    });

    group('deleteProfile', () {
      test('should delete profile successfully', () async {
        final profile = UserProfile.withDefaults(
          id: 'user123',
          username: 'testuser',
        );
        await repository.saveProfile(profile);

        final deleteResult = await repository.deleteProfile();
        final getResult = await repository.getCurrentProfile();

        expect(deleteResult.isOk, true);
        expect(getResult.getOrNull(), isNull);
      });
    });

    group('hasProfile', () {
      test('should return false when no profile exists', () async {
        final result = await repository.hasProfile();
        expect(result, false);
      });

      test('should return true when profile exists', () async {
        final profile = UserProfile.withDefaults(
          id: 'user123',
          username: 'testuser',
        );
        await repository.saveProfile(profile);

        final result = await repository.hasProfile();
        expect(result, true);
      });
    });
  });
}

