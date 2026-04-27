import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A bundle of access + refresh tokens with their respective expiry instants.
///
/// Returned by [SecureTokenStorage.read] and consumed by
/// [SecureTokenStorage.save].
class TokenBundle {
  /// Creates a [TokenBundle].
  const TokenBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  /// Short-lived bearer token sent with API requests.
  final String accessToken;

  /// Long-lived token used to mint new [accessToken]s.
  final String refreshToken;

  /// Instant after which [accessToken] must not be used.
  final DateTime accessExpiresAt;

  /// Instant after which [refreshToken] is also invalid and the user must
  /// log in again.
  final DateTime refreshExpiresAt;

  /// Whether [accessToken] has expired relative to [now] (defaults to UTC
  /// wall-clock).
  bool isAccessExpired({DateTime? now}) =>
      !(now ?? DateTime.now().toUtc()).isBefore(accessExpiresAt);

  /// Whether [refreshToken] has expired — i.e. the session is unrecoverable.
  bool isRefreshExpired({DateTime? now}) =>
      !(now ?? DateTime.now().toUtc()).isBefore(refreshExpiresAt);
}

/// Persists OAuth-style access + refresh tokens in the platform's secure
/// enclave (Android Keystore / iOS Keychain) via `flutter_secure_storage`.
///
/// Usage:
///
/// ```dart
/// final storage = SecureTokenStorage();
///
/// await storage.save(
///   TokenBundle(
///     accessToken: 'eyJhbGciOi...',
///     refreshToken: 'def50200...',
///     accessExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
///     refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
///   ),
/// );
///
/// final tokens = await storage.read();
/// if (tokens == null || tokens.isRefreshExpired()) {
///   // user must log in again
/// }
/// ```
///
/// Multiple [SecureTokenStorage] instances can coexist on the same device
/// by passing distinct [keyPrefix] values — useful for multi-account apps
/// or when isolating dev/staging credentials.
class SecureTokenStorage {
  /// Creates a [SecureTokenStorage].
  ///
  /// [storage] is injected for testing — production callers should leave it
  /// null and let the platform default be used.
  ///
  /// [keyPrefix] namespaces every entry written to secure storage. Defaults
  /// to no prefix; pass e.g. `'myapp_'` or `'staging_'` to isolate stores.
  const SecureTokenStorage({
    FlutterSecureStorage? storage,
    String keyPrefix = '',
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _prefix = keyPrefix;

  final FlutterSecureStorage _storage;
  final String _prefix;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kAccessExpiry = 'access_expiry';
  static const _kRefreshExpiry = 'refresh_expiry';

  String get _accessKey => '$_prefix$_kAccess';
  String get _refreshKey => '$_prefix$_kRefresh';
  String get _accessExpiryKey => '$_prefix$_kAccessExpiry';
  String get _refreshExpiryKey => '$_prefix$_kRefreshExpiry';

  /// Persists [bundle] in secure storage. Existing values under the same
  /// [keyPrefix] are overwritten atomically per-key.
  Future<void> save(TokenBundle bundle) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: bundle.accessToken),
      _storage.write(key: _refreshKey, value: bundle.refreshToken),
      _storage.write(
        key: _accessExpiryKey,
        value: bundle.accessExpiresAt.toUtc().toIso8601String(),
      ),
      _storage.write(
        key: _refreshExpiryKey,
        value: bundle.refreshExpiresAt.toUtc().toIso8601String(),
      ),
    ]);
  }

  /// Returns the persisted [TokenBundle], or `null` if any of the four
  /// fields is missing (e.g. fresh install, after [clear], or partial write).
  Future<TokenBundle?> read() async {
    final results = await Future.wait([
      _storage.read(key: _accessKey),
      _storage.read(key: _refreshKey),
      _storage.read(key: _accessExpiryKey),
      _storage.read(key: _refreshExpiryKey),
    ]);

    final access = results[0];
    final refresh = results[1];
    final accessExpiry = results[2];
    final refreshExpiry = results[3];

    if (access == null ||
        refresh == null ||
        accessExpiry == null ||
        refreshExpiry == null) {
      return null;
    }

    return TokenBundle(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: DateTime.parse(accessExpiry),
      refreshExpiresAt: DateTime.parse(refreshExpiry),
    );
  }

  /// Deletes all four entries under the configured [keyPrefix].
  ///
  /// Other entries in secure storage (under different prefixes or unrelated
  /// keys) are not touched.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _accessExpiryKey),
      _storage.delete(key: _refreshExpiryKey),
    ]);
  }
}
