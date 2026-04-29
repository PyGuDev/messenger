# Contract: Chat Session Behavior

## Purpose

Defines the expected client-side behavior for message timeline restore, per-chat state isolation, and contact-to-chat launch during the stabilization effort.

## 1. Timeline Restore Contract

- A chat with previously synced history must restore its last successful local timeline before or alongside network refresh.
- A chat with no prior successful sync and no connectivity must render an explicit "history unavailable offline" state.
- Cached and fetched messages must reconcile by chat ownership and message identity so duplicates and cross-chat leakage do not appear.
- Session-specific draft/media/camera state must not persist into another chat after navigation.

## 2. Session Ownership Contract

- `MessagesBloc` ownership is route/session scoped, not app-global.
- Entering `/chat/:id` creates or binds exactly one message session for that chat.
- Leaving the route tears down WebSocket listeners, media-recording state, and any session-only resources associated with that chat instance.

## 3. Contact-to-Chat Launch Contract

- UI entry points dispatch an intent to open a direct conversation; they do not call chat APIs directly.
- Canonical direct-chat behavior is:
  1. Check for an existing one-to-one chat for the target contact.
  2. Reuse it if present.
  3. Create a new direct chat only if no existing match is found.
- If launch fails, the user remains on a recoverable screen and receives a clear failure message.
- Repeated launch attempts while one request is active must not create duplicate chats.

## 4. Documentation Alignment

- If implementation requires contract changes to existing chat lookup/create semantics, update `docs/chat_api.md` in the same change.
- If media/file behavior or environment setup expectations change, update `docs/FRONTEND_API_GUIDE.md` in the same change.
