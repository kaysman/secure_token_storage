# Changelog

## 0.1.0

- Initial release.
- `TokenBundle` value type with access/refresh tokens and per-token expiry
  timestamps.
- `SecureTokenStorage` with `save`, `read`, and `clear` operations backed by
  `flutter_secure_storage`.
- Configurable `keyPrefix` for multi-account / dev-staging isolation.
