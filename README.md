# secure_token_storage

[![pub package](https://img.shields.io/pub/v/secure_token_storage.svg)](https://pub.dev/packages/secure_token_storage)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A tiny, opinionated wrapper around
[`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
for persisting OAuth-style **access + refresh** tokens with **separate expiry
timestamps** in the platform's secure enclave (Android Keystore / iOS
Keychain).

If you've written this code in three different apps already, this is that
code — extracted, tested, and reusable.

## Features

- One `TokenBundle` value type holds both tokens and both expiries.
- `isAccessExpired()` / `isRefreshExpired()` helpers with injectable clock for
  testing.
- Atomic per-key writes with all-or-nothing read semantics — partial state
  returns `null` instead of half-decoded garbage.
- `keyPrefix` for multi-account or dev/staging isolation on the same device.
- Pure `flutter_secure_storage` under the hood: no extra native code, no extra
  permissions.

## Install

```sh
flutter pub add secure_token_storage
```

## Usage

```dart
import 'package:secure_token_storage/secure_token_storage.dart';

final storage = const SecureTokenStorage();

// After successful login:
await storage.save(
  TokenBundle(
    accessToken: response.accessToken,
    refreshToken: response.refreshToken,
    accessExpiresAt:
        DateTime.now().toUtc().add(Duration(seconds: response.expiresIn)),
    refreshExpiresAt:
        DateTime.now().toUtc().add(const Duration(days: 30)),
  ),
);

// On app start:
final tokens = await storage.read();
if (tokens == null || tokens.isRefreshExpired()) {
  // user must log in again
} else if (tokens.isAccessExpired()) {
  // call your refresh endpoint, then storage.save(...) the new bundle
} else {
  // use tokens.accessToken
}

// On logout:
await storage.clear();
```

### Multi-account / staging isolation

```dart
final prod = const SecureTokenStorage();
final staging = const SecureTokenStorage(keyPrefix: 'staging_');
```

The two stores never collide — `clear()` on one leaves the other intact.

## API

### `TokenBundle`

| Field | Type | Notes |
|---|---|---|
| `accessToken` | `String` | Sent as `Authorization: Bearer …`. |
| `refreshToken` | `String` | Used to mint a new access token. |
| `accessExpiresAt` | `DateTime` | Stored as ISO-8601 UTC. |
| `refreshExpiresAt` | `DateTime` | Stored as ISO-8601 UTC. |

| Method | Returns |
|---|---|
| `isAccessExpired({DateTime? now})` | `true` when `now ≥ accessExpiresAt`. |
| `isRefreshExpired({DateTime? now})` | `true` when `now ≥ refreshExpiresAt`. |

### `SecureTokenStorage`

| Constructor parameter | Default | Notes |
|---|---|---|
| `storage` | platform default | Inject your own for testing. |
| `keyPrefix` | `''` | Namespaces every entry. |

| Method | Behavior |
|---|---|
| `save(TokenBundle)` | Writes all 4 entries. |
| `read()` | Returns the bundle, or `null` if any entry is missing. |
| `clear()` | Deletes all 4 entries under the configured prefix. |

## Testing your own code

`SecureTokenStorage` accepts an injected `FlutterSecureStorage` so you can
mock it. See [`test/secure_token_storage_test.dart`](test/secure_token_storage_test.dart)
for a worked example using [`mocktail`](https://pub.dev/packages/mocktail).

```sh
flutter test
```

## Example app

A small interactive demo lives in [`example/`](example):

```sh
cd example
flutter run
```

## License

MIT — see [LICENSE](LICENSE).
