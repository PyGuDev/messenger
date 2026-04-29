# Implementation Plan: Flutter Stabilization Plan

**Branch**: `001-message-actions` | **Date**: 2026-04-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-flutter-stabilization/spec.md`

## Summary

Stabilize the messenger client by making message cache restoration deterministic per chat, scoping message and media lifecycle to the active conversation, moving contact-to-chat orchestration out of widget code into application state, replacing hardcoded network environment values with validated startup configuration, and upgrading automated coverage from placeholder smoke checks to behavior-focused regression tests.

## Technical Context

**Language/Version**: Dart `^3.11.1`, Flutter mobile/web client  
**Primary Dependencies**: `flutter_bloc`, `dio`, `go_router`, `get_it`, `sqflite`, `web_socket_channel`, `shared_preferences`, `flutter_secure_storage`, `camera`, `flutter_cache_manager`  
**Storage**: Local SQLite via `sqflite` for messages/chats, secure storage for auth tokens, shared preferences for lightweight cached profile/config flags  
**Testing**: `flutter_test` for widget/unit coverage, analyzer via `flutter analyze`  
**Target Platform**: Flutter Android, iOS, macOS, web  
**Project Type**: Feature-first Flutter client  
**Performance Goals**: Cached chat history renders immediately on reopen; contact-to-chat launch resolves in one app-controlled flow; configuration errors surface before affected network calls start  
**Constraints**: Preserve existing BLoC + DI architecture; keep offline restore behavior; do not break documented chat/file contracts without doc updates; support Russian and English UX states; no new state-management framework  
**Scale/Scope**: Touches `lib/features/messages`, `lib/features/chats`, `lib/features/contacts`, `lib/core/network`, `lib/core/di`, `lib/core/navigation`, and associated tests/docs for one coordinated stabilization slice

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Feature work preserves `lib/features/<feature>` boundaries and keeps cross-feature dependencies out of presentation code.
- [x] UI state and user actions flow through BLoC or an approved equivalent already used in the codebase; business logic is not introduced in widgets/screens.
- [x] Local storage, cache behavior, retry/reconnect flow, and offline/error handling are defined for every data mutation or sync path touched by this feature.
- [x] API, WebSocket, auth, or file-transfer changes are reflected in the relevant `docs/` contract files, or the intended contract delta is recorded here.
- [x] The feature is planned as an independently testable vertical slice with automated verification for the primary journey and affected failure modes.

## Project Structure

### Documentation (this feature)

```text
specs/001-flutter-stabilization/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── chat-session-behavior.md
│   └── runtime-config.md
└── tasks.md
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── cache/
│   ├── di/
│   ├── local/
│   ├── navigation/
│   ├── network/
│   └── security/
├── shared/
├── features/
│   ├── chats/
│   │   ├── data/
│   │   └── presentation/
│   ├── contacts/
│   │   └── presentation/
│   └── messages/
│       ├── data/
│       └── presentation/
└── l10n/

test/
├── message_model_test.dart
└── widget_test.dart

docs/
├── chat_api.md
└── FRONTEND_API_GUIDE.md
```

**Structure Decision**: Keep the existing Flutter feature-first layout. Implement message/session fixes inside `messages`, contact-launch orchestration inside `chats` plus navigation wiring, configuration validation inside `core/network` and `core/di`, and verification in `test/` with room to add feature-scoped tests.

## Phase 0: Research

Research output: [research.md](./research.md)

Key outcomes adopted for implementation:

1. Introduce one validated application environment object resolved during app startup, then injected into network clients instead of reading hardcoded host constants.
2. Scope `MessagesBloc` and camera/media session lifecycle to the active chat route rather than registering one app-global instance in `main.dart`.
3. Move contact-to-chat resolution into application state so the UI dispatches intent and renders progress/error only.
4. Normalize message cache serialization/deserialization around one canonical message shape and explicit offline-first restore rules.
5. Replace ad hoc production logging and placeholder tests with focused diagnostics and regression coverage for cache, routing, and failure behavior.

## Phase 1: Design & Contracts

### Data Model

Design output: [data-model.md](./data-model.md)

Primary modeled objects:

- `ChatSession`
- `MessageTimelineCacheRecord`
- `ContactConversationLaunch`
- `RuntimeEnvironmentProfile`
- `ConfigurationErrorState`

### Contract Artifacts

Contract outputs:

- [contracts/chat-session-behavior.md](./contracts/chat-session-behavior.md)
- [contracts/runtime-config.md](./contracts/runtime-config.md)

Planned documentation alignment:

- Update `docs/chat_api.md` if chat lookup/create or message loading assumptions need contract clarification.
- Update `docs/FRONTEND_API_GUIDE.md` if file-service/environment setup guidance changes.
- Update `README.md` for environment provisioning and verification workflow.

### Quickstart

Verification flow: [quickstart.md](./quickstart.md)

### Agent Context Update

`AGENTS.md` will point subsequent commands at `specs/001-flutter-stabilization/plan.md`.

## Phase 2: Implementation Strategy

Implementation will be decomposed into these task groups:

1. Environment bootstrap and validation
2. Message cache/model consistency hardening
3. Per-chat `MessagesBloc` and camera/session lifecycle scoping
4. Contact-to-chat orchestration migration into application state/navigation
5. Diagnostics cleanup and regression test replacement
6. Documentation synchronization for runtime config and chat/file contracts

Each group remains testable as a vertical slice, but sequencing should prioritize cache correctness first, then state ownership, then flow orchestration, followed by environment/diagnostics/test hardening where dependencies permit.

## Post-Design Constitution Check

- [x] Feature boundaries remain feature-first: messaging changes stay in `messages`, conversation-launch logic moves into `chats`/navigation rather than leaking through `contacts` UI, and environment concerns stay in `core/network` + DI.
- [x] Planned state flow is BLoC-centered: widgets dispatch intents, while chat launch, cache restore, and session teardown live in explicit state/event handlers.
- [x] Offline/cache behavior is explicitly designed: cached timeline restore, first-sync offline state, duplicate prevention, reconnect refresh, and session cleanup are defined.
- [x] Contract-sensitive work is tracked: existing docs remain authoritative and are scheduled for synchronized updates if behavior or setup expectations change.
- [x] Verification is first-class: analyzer cleanup, model/cache tests, route/state tests, and primary failure-path checks are included in the plan.

## Complexity Tracking

No constitution violations are required for this plan.
