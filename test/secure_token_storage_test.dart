import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_token_storage/secure_token_storage.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('TokenBundle', () {
    final bundle = TokenBundle(
      accessToken: 'a',
      refreshToken: 'r',
      accessExpiresAt: DateTime.utc(2030, 1, 1, 12),
      refreshExpiresAt: DateTime.utc(2030, 6, 1, 12),
    );

    test('isAccessExpired is true past the expiry instant', () {
      expect(
        bundle.isAccessExpired(now: DateTime.utc(2030, 1, 1, 13)),
        isTrue,
      );
    });

    test('isAccessExpired is false strictly before the expiry instant', () {
      expect(
        bundle.isAccessExpired(now: DateTime.utc(2030, 1, 1, 11, 59)),
        isFalse,
      );
    });

    test('isAccessExpired is true exactly at the expiry instant', () {
      expect(
        bundle.isAccessExpired(now: DateTime.utc(2030, 1, 1, 12)),
        isTrue,
      );
    });

    test('isRefreshExpired uses the refresh expiry', () {
      expect(
        bundle.isRefreshExpired(now: DateTime.utc(2030, 7, 1)),
        isTrue,
      );
      expect(
        bundle.isRefreshExpired(now: DateTime.utc(2030, 5, 1)),
        isFalse,
      );
    });
  });

  group('SecureTokenStorage', () {
    late _MockSecureStorage backend;
    late SecureTokenStorage storage;

    setUp(() {
      backend = _MockSecureStorage();
      storage = SecureTokenStorage(storage: backend);

      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => backend.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});
    });

    test('save writes all four keys with ISO-8601 UTC expiries', () async {
      final bundle = TokenBundle(
        accessToken: 'access',
        refreshToken: 'refresh',
        accessExpiresAt: DateTime.utc(2030, 1, 1, 12),
        refreshExpiresAt: DateTime.utc(2030, 6, 1, 12),
      );

      await storage.save(bundle);

      verify(() => backend.write(key: 'access_token', value: 'access'))
          .called(1);
      verify(() => backend.write(key: 'refresh_token', value: 'refresh'))
          .called(1);
      verify(
        () => backend.write(
          key: 'access_expiry',
          value: '2030-01-01T12:00:00.000Z',
        ),
      ).called(1);
      verify(
        () => backend.write(
          key: 'refresh_expiry',
          value: '2030-06-01T12:00:00.000Z',
        ),
      ).called(1);
    });

    test('read returns a TokenBundle when all four keys are present',
        () async {
      when(() => backend.read(key: 'access_token'))
          .thenAnswer((_) async => 'access');
      when(() => backend.read(key: 'refresh_token'))
          .thenAnswer((_) async => 'refresh');
      when(() => backend.read(key: 'access_expiry'))
          .thenAnswer((_) async => '2030-01-01T12:00:00.000Z');
      when(() => backend.read(key: 'refresh_expiry'))
          .thenAnswer((_) async => '2030-06-01T12:00:00.000Z');

      final bundle = await storage.read();

      expect(bundle, isNotNull);
      expect(bundle!.accessToken, 'access');
      expect(bundle.refreshToken, 'refresh');
      expect(bundle.accessExpiresAt, DateTime.utc(2030, 1, 1, 12));
      expect(bundle.refreshExpiresAt, DateTime.utc(2030, 6, 1, 12));
    });

    test('read returns null when any field is missing', () async {
      when(() => backend.read(key: 'access_token'))
          .thenAnswer((_) async => 'access');
      when(() => backend.read(key: 'refresh_token'))
          .thenAnswer((_) async => null);
      when(() => backend.read(key: 'access_expiry'))
          .thenAnswer((_) async => '2030-01-01T12:00:00.000Z');
      when(() => backend.read(key: 'refresh_expiry'))
          .thenAnswer((_) async => '2030-06-01T12:00:00.000Z');

      expect(await storage.read(), isNull);
    });

    test('clear deletes all four keys', () async {
      await storage.clear();

      verify(() => backend.delete(key: 'access_token')).called(1);
      verify(() => backend.delete(key: 'refresh_token')).called(1);
      verify(() => backend.delete(key: 'access_expiry')).called(1);
      verify(() => backend.delete(key: 'refresh_expiry')).called(1);
    });

    test('keyPrefix namespaces every entry', () async {
      final prefixed =
          SecureTokenStorage(storage: backend, keyPrefix: 'staging_');

      await prefixed.clear();

      verify(() => backend.delete(key: 'staging_access_token')).called(1);
      verify(() => backend.delete(key: 'staging_refresh_token')).called(1);
      verify(() => backend.delete(key: 'staging_access_expiry')).called(1);
      verify(() => backend.delete(key: 'staging_refresh_expiry')).called(1);
    });
  });
}
