# Feature Specification: Flutter Stabilization Plan

**Feature Branch**: `001-message-actions`

**Created**: 2026-04-22

**Status**: Partially Implemented

**Current Behavior**: [Product Baseline 002](../002-document-current-product/spec.md)
**Input**: User description: "https://github.com/PyGuDev/messenger/issues/32"

## Clarifications

### Session 2026-04-22

- Q: Что должно происходить, если пользователь открывает офлайн чат, который еще ни разу успешно не синхронизировался? → A: Показывать состояние "история недоступна офлайн" до первой успешной синхронизации.
- Q: Какое правило должно считаться каноническим для запуска диалога из профиля контакта? → A: Открывать существующий direct-чат, если он уже есть, иначе создавать новый.
- Q: Как приложение должно вести себя, если runtime-конфигурация окружения отсутствует или некорректна? → A: Переходить в явную блокирующую ошибку конфигурации до начала сетевых сценариев.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Trust Message History (Priority: P1)

As a messenger user, I want each chat to show the correct message history whether the app is online or temporarily offline, so I can continue a conversation without duplicated, missing, or mismatched messages.

**Why this priority**: Message accuracy is the core value of the product. If cached and live messages diverge, users lose trust in every conversation.

**Independent Test**: Can be fully tested by opening a chat with previously loaded messages, disconnecting connectivity, reopening the chat, and confirming the same timeline appears without corruption or cross-chat leakage.

**Acceptance Scenarios**:

1. **Given** a user has previously loaded a chat, **When** they reopen that chat without network access, **Then** the app shows the latest successfully synced message timeline for that chat.
2. **Given** a chat has cached messages and newer server messages become available, **When** the app reconnects and refreshes the chat, **Then** the visible timeline is updated without duplicate, reordered, or malformed entries.
3. **Given** a user switches from one chat to another, **When** the second chat loads, **Then** no messages, attachments, or draft state from the first chat appear in the second chat session.
4. **Given** a chat has never completed an initial successful sync, **When** the user opens it while offline, **Then** the app shows a clear chat-specific state explaining that history is unavailable offline until first sync completes.

---

### User Story 2 - Start Conversations Predictably (Priority: P2)

As a user viewing a contact profile, I want starting or reopening a conversation to follow one consistent flow, so the app always opens the correct chat without UI-only logic making navigation unreliable.

**Why this priority**: Starting a chat is a high-frequency action. It must behave consistently and remain maintainable as the app grows.

**Independent Test**: Can be fully tested by opening a contact profile, initiating a conversation, and verifying that the app either reuses an existing chat or creates the correct one through application-controlled state handling.

**Acceptance Scenarios**:

1. **Given** a direct chat with a contact already exists, **When** the user taps the action to message that contact, **Then** the app opens the existing chat instead of creating a duplicate conversation.
2. **Given** no direct chat exists with a contact, **When** the user starts a conversation from that contact profile, **Then** the app creates the conversation through the standard application flow and opens it after creation succeeds.
3. **Given** chat creation fails, **When** the user starts a conversation from a contact profile, **Then** the app keeps the user informed and does not navigate into a broken or partial chat state.

---

### User Story 3 - Ship With Operational Confidence (Priority: P3)

As a product owner preparing releases, I want runtime configuration, diagnostics, and regression coverage to be reliable, so builds can target the right environment and critical messaging flows stay protected from repeat failures.

**Why this priority**: Release readiness depends on predictable environment setup, actionable diagnostics, and tests that protect high-risk behavior.

**Independent Test**: Can be fully tested by running the app against a non-default environment configuration, exercising primary messaging flows, and confirming meaningful automated tests cover routing, state, and cache behavior while analyzer output remains free of known avoidable warnings.

**Acceptance Scenarios**:

1. **Given** a release build needs different service endpoints, **When** maintainers supply runtime environment values, **Then** the app uses those values without source edits.
2. **Given** required runtime environment values are missing or invalid, **When** the app starts or initializes network-dependent flows, **Then** the app enters a clear blocking configuration-error state before any affected network requests are attempted.
3. **Given** maintainers review the codebase before release, **When** analyzer and automated tests run, **Then** placeholder tests are replaced by production-relevant coverage and avoidable warning noise is removed.
4. **Given** a critical messaging failure occurs, **When** maintainers inspect diagnostics, **Then** logs and error reporting provide useful context without relying on ad hoc debug-only statements scattered through production flows.

---

### Edge Cases

- A chat is opened offline before any successful sync has ever completed for that conversation, in which case the app shows a chat-specific "history unavailable offline" state instead of an empty or misleading timeline.
- Cached messages contain older field shapes than the latest server response.
- The user changes chats while a message load, media preparation, or camera-related action is still in progress.
- Contact-to-chat navigation is triggered repeatedly before the first request finishes, and the app must still resolve to one canonical direct chat without creating duplicates.
- Runtime environment values are missing, incomplete, or inconsistent for one backend while others are configured, and the app must surface a blocking configuration error before affected network flows start.
- Analyzer cleanup removes noisy warnings but must not hide genuinely actionable failures.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST persist message timelines in a format that can be read back into the same user-visible message state without losing required fields or changing meaning.
- **FR-002**: The system MUST load the most recent successfully synced message timeline for an individual chat when that chat is reopened while offline or during network recovery.
- **FR-002a**: The system MUST show a chat-specific "history unavailable offline" state when a chat is opened offline before its first successful sync has completed.
- **FR-003**: The system MUST reconcile cached and newly fetched messages for a chat without showing duplicates, malformed items, or messages from another chat.
- **FR-004**: The system MUST scope message state, media preparation state, and camera-related state to the active chat session so activity in one conversation does not leak into another.
- **FR-005**: The system MUST reset or dispose chat-session-specific resources when the user leaves a chat or switches to a different one.
- **FR-006**: The system MUST handle the contact-to-chat action through application-controlled state and navigation logic rather than widget-local orchestration.
- **FR-007**: The system MUST reuse an existing direct chat with a contact when one already exists.
- **FR-008**: The system MUST create and open a new direct chat when none exists, and it MUST keep the user on a recoverable screen if creation fails.
- **FR-008a**: The system MUST treat "reuse existing direct chat, otherwise create one" as the canonical contact-to-chat rule across all supported contact-entry flows.
- **FR-009**: The system MUST allow maintainers to provide runtime environment configuration for network-dependent features without modifying application source files for each deployment target.
- **FR-010**: The system MUST surface missing or invalid runtime environment configuration as a clear blocking configuration error before affected network-dependent features begin execution.
- **FR-011**: The system MUST reduce avoidable analyzer noise and replace placeholder automated tests with coverage for routing, chat state transitions, and message cache behavior.
- **FR-012**: The system MUST preserve existing chat and file-service integration contracts unless matching documentation updates are made in the same change.

### Key Entities *(include if feature involves data)*

- **Chat Session**: A user’s active interaction context for one conversation, including the selected chat, visible message timeline, draft and media state, and session-bound resources.
- **Message Timeline Cache**: The locally stored representation of a chat’s message history that is used to restore the conversation during offline use and to merge with new server data.
- **Conversation Launch Request**: The user intent to open or create a direct chat from another part of the app, including the target contact and the resulting navigation outcome.
- **Direct Chat Match**: The canonical determination of whether a one-to-one conversation with a contact already exists and must be reopened instead of duplicated.
- **Runtime Environment Profile**: The set of backend endpoint and environment values supplied for a given deployment target.
- **Configuration Error State**: The explicit blocking state shown when required runtime environment values are missing or invalid for the selected deployment target.

## Architecture & Integration Impact *(mandatory for code changes)*

- **Feature Boundary**: Changes will affect the `messages`, `chats`, and `contacts` feature areas plus shared dependency/configuration infrastructure in `lib/core/`. Responsibilities must remain split so message presentation does not absorb networking or environment setup concerns.
- **State Flow**: Chat opening, message loading, offline restoration, retry handling, and session teardown must be coordinated through application state flows. Widget screens may trigger intents, but durable decisions and transitions belong in the app’s established state-management layer.
- **Local Data / Offline Behavior**: Message cache reads and writes must remain chat-specific, survive temporary disconnects, and recover cleanly after reconnect. Session cleanup must prevent stale media, camera, and draft state from persisting into another conversation.
- **External Contracts**: Existing chat and file-service interactions remain in scope. Any change that affects request shape, attachment handling, authentication assumptions, or error expectations must be reflected in `docs/chat_api.md` and `docs/FRONTEND_API_GUIDE.md`.
- **Test Plan**: Automated coverage must be added or updated for cached message restoration, chat-to-chat state isolation, contact-to-chat launch behavior, environment configuration handling, and contract-sensitive failure paths.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In release-readiness testing, 100% of reopened chats display the last successfully synced message timeline for that chat when the device is temporarily offline.
- **SC-002**: During regression testing across repeated chat switches, no cross-chat message leakage, attachment leakage, or stale camera state is observed in the primary messaging flow.
- **SC-003**: Users can start or reopen a direct conversation from a contact profile in one uninterrupted flow in at least 95% of valid attempts during acceptance testing.
- **SC-004**: Maintainers can prepare a build for a different deployment environment without editing source files, and missing or invalid required configuration is detected before any affected network scenario begins.
- **SC-005**: Automated tests cover the primary routing, state, and cache behaviors called out in this specification, and the default placeholder widget smoke test is no longer the only broad UI regression check.

## Assumptions

- The umbrella issue is intended to be planned as one coordinated stabilization effort, even if implementation later lands in smaller pull requests.
- Existing backend chat and file-service contracts remain the source of truth unless updated documentation is included with any behavior change.
- The current app should continue supporting offline viewing of previously synced conversations rather than introducing a new offline authoring model.
- Direct-contact messaging remains a one-to-one conversation model that should avoid duplicate chat creation.
- Reusing an existing one-to-one conversation is the default and required behavior when a matching direct chat already exists.
- Release readiness for this effort is defined by stable conversation behavior, configurable environments, reduced analyzer noise, and meaningful automated regression coverage.
- Missing or invalid required environment values are considered release-blocking rather than recoverable at runtime for this effort.

## Documentation Impact

- Update [README.md](/Users/admin/myprojects/messenger/README.md) if environment configuration or testing workflow expectations change for contributors.
- Keep [docs/chat_api.md](/Users/admin/myprojects/messenger/docs/chat_api.md) aligned with any messaging contract or error-handling changes.
- Keep [docs/FRONTEND_API_GUIDE.md](/Users/admin/myprojects/messenger/docs/FRONTEND_API_GUIDE.md) aligned with any file upload, download, or environment-related behavior changes.
- Implemented user-visible behavior is described by [Product Baseline 002](../002-document-current-product/spec.md). This feature specification remains authoritative only for unfinished stabilization requirements tracked in `tasks.md`.
