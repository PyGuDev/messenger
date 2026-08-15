# messenger

Flutter messenger client with feature-first modules for auth, chats, messages,
contacts, profile, and network state.

## Project Shape

- `lib/features/` contains feature modules with separated `presentation` and `data`
  responsibilities.
- `lib/core/` contains cross-cutting infrastructure such as navigation, networking,
  security, persistence, and dependency injection.
- `lib/shared/` contains reusable UI and theme primitives used by multiple features.
- `docs/` contains integration contracts that must stay aligned with client behavior.

## Working Rules

- State changes belong in BLoC flows, not in widgets.
- Contract changes must update the relevant files in `docs/` in the same change.
- Changes to business logic, persistence, navigation, or integrations require
  automated test updates in `test/`.
- New feature work should preserve the existing feature-first structure.

## Documentation

- [Documentation index](./docs/README.md)
- [Current Product Baseline](./specs/002-document-current-product/spec.md)
- [Domain glossary](./CONTEXT.md)
- [Chat Service API](./docs/chat_api.md)
- [File Service API](./docs/FRONTEND_API_GUIDE.md)
- [Auth/Profile client expectations](./docs/auth_api.md)

## Runtime Configuration

The client resolves all backend endpoints at startup and blocks
network-dependent flows when any required value is missing or invalid.

Dart defines take precedence over the optional `.env` asset. Use `.env` only as
a local fallback for keys that are not supplied through `--dart-define`. An
empty or malformed Dart define is treated as configuration input and therefore
causes the blocking configuration error rather than falling back to `.env`.

Use these defines for local or release verification:

```bash
flutter run \
  --dart-define=APP_ENVIRONMENT_NAME=local \
  --dart-define=APP_AUTH_BASE_URL=https://auth.example.com/auth/api/v1 \
  --dart-define=APP_CHAT_BASE_URL=https://chat.example.com/room/api/v1 \
  --dart-define=APP_FILE_BASE_URL=https://files.example.com/file \
  --dart-define=APP_WS_BASE_URL=wss://chat.example.com/room/ws
```

If one of these values is missing or malformed, the app renders a blocking
configuration error screen before authenticated networking, chat loading, or
file transfer flows begin.
