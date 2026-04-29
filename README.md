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

## Runtime Configuration

The client now reads all backend endpoints from Dart defines at startup and
blocks network-dependent flows when any required value is missing or invalid.

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

## References

- [Flutter documentation](https://docs.flutter.dev/)
- [Chat API contract](./docs/chat_api.md)
- [File service integration guide](./docs/FRONTEND_API_GUIDE.md)
