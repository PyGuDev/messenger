# Quickstart: Flutter Stabilization Plan

## Goal

Verify the stabilization slice end to end once implementation is complete.

## Prerequisites

1. Provide valid environment values for auth/chat/file/WebSocket endpoints using the project’s chosen configuration path.
2. Ensure a test user can access at least one existing direct chat and one contact without an existing direct chat.
3. Ensure the local database can be reset between runs for clean cache verification.

## Verification Steps

### 1. Static validation

```bash
flutter analyze
flutter test
```

Expected result:

- No avoidable analyzer noise from the touched stabilization areas
- Regression tests cover cache/model behavior, route/state ownership, and configuration validation

### 2. Cached message restore

1. Open an existing chat while online.
2. Confirm messages load and the timeline is cached.
3. Disable connectivity.
4. Reopen the same chat.

Expected result:

- The last successfully synced timeline appears for that chat.
- Messages from other chats do not appear.

### 3. Offline first-sync behavior

1. Use a chat that has never been synced locally.
2. Disable connectivity.
3. Open the chat.

Expected result:

- The app shows a clear "history unavailable offline" state for that chat instead of a misleading empty timeline.

### 4. Contact-to-chat canonical flow

1. From a contact profile with an existing direct chat, tap "Написать".
2. Repeat with a contact that has no existing direct chat.
3. Repeat fast taps while the first request is still processing.

Expected result:

- Existing direct chat is reopened when present.
- New direct chat is created only when no match exists.
- Repeated taps do not create duplicate chats.

### 5. Session isolation

1. Open chat A, begin a media or draft action, then switch to chat B.
2. Return to chat A.

Expected result:

- Chat B never displays chat A timeline/media state.
- Chat-session resources are torn down and recreated predictably per route.

### 6. Configuration failure path

1. Start the app with one required environment value missing or invalid.

Expected result:

- The app enters a blocking configuration-error state before affected network requests begin.
- The error clearly indicates a configuration problem rather than a generic transport failure.
