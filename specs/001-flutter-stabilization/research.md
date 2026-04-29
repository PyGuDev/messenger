# Research: Flutter Stabilization Plan

## Decision 1: Resolve environment configuration once at startup through an injected app environment object

**Decision**: Replace hardcoded network host/base URLs with a single runtime-resolved environment object that is validated before `Dio`, WebSocket, or file-service clients are created.

**Rationale**: The current `NetworkModule` hardcodes `192.168.8.235:80`, which prevents deployment-target changes without source edits and makes misconfiguration invisible until network failures occur. Centralizing environment resolution lets startup fail fast with an explicit configuration error state, matching the clarified spec.

**Alternatives considered**:

- Keep hardcoded constants and edit source per environment: rejected because it violates the specification and raises release risk.
- Lazily resolve environment values inside each network client: rejected because it duplicates validation and can produce inconsistent partial startup.
- Silently fall back to defaults when values are missing: rejected because the clarified spec requires blocking misconfiguration before network flows begin.

## Decision 2: Scope message state to the active chat route instead of one app-global `MessagesBloc`

**Decision**: Remove the app-global `MessagesBloc` provider from `main.dart` and create chat-scoped message state at the `/chat/:id` route/screen boundary, with explicit teardown when leaving the chat.

**Rationale**: The current app registers `MessagesBloc` once in `main.dart`, while `MessagesScreen` also owns camera/media lifecycle. A single long-lived bloc increases cross-chat leakage risk for timeline state, optimistic messages, subscriptions, and session resources. Route-scoped creation matches the requirement that one chat’s state must not bleed into another.

**Alternatives considered**:

- Keep a singleton/global `MessagesBloc` and manually reset on every navigation: rejected because resets are easy to miss and keep session coupling implicit.
- Introduce a second state-management library for per-screen session control: rejected because it violates the constitution’s BLoC constraint.
- Store multiple chat sessions inside one mega-bloc: rejected because it complicates teardown, testing, and bug isolation for this stabilization scope.

## Decision 3: Move contact-to-chat orchestration into application state coordinated by chats/navigation logic

**Decision**: Replace the direct `Dio` request flow inside `ContactProfileScreen` with a BLoC-driven contact-to-chat launch flow that resolves "reuse existing direct chat, otherwise create one" as the canonical rule and emits navigation/result states.

**Rationale**: `ContactProfileScreen` currently performs API calls, duplicate-chat lookup logic, progress state, snackbars, and navigation directly in the widget. That violates the constitution’s thin-widget rule and makes retry/error behavior harder to test. Moving this into state coordination creates a single authoritative direct-chat launch path.

**Alternatives considered**:

- Leave logic in the widget and clean it up incrementally: rejected because business logic would still remain in UI code.
- Create a separate ad hoc service invoked directly by the widget: rejected because state transitions and user-facing progress/error handling still need BLoC ownership.
- Always create a new direct chat: rejected because the clarified spec requires reuse of an existing matching chat.

## Decision 4: Canonicalize cached message shape and merge behavior around one local timeline model

**Decision**: Use one canonical local message representation for both cache writes and cache reads, and define merge rules so reconnect/network refresh replaces or reconciles cached items by chat and message identity without duplicates.

**Rationale**: `MessagesLocalDataSource` and `MessageModel` already expose mismatches such as `text` vs `body`, attachment field normalization, and optimistic/client IDs. A canonical cache contract is necessary to prevent malformed restore, duplicate optimistic messages, and cross-chat contamination during refresh.

**Alternatives considered**:

- Trust current `replace` inserts and per-message parsing without a formal cache contract: rejected because the umbrella issue already identifies cache inconsistency as a primary defect.
- Skip local canonicalization and map everything only at the UI layer: rejected because corruption originates in the persistence boundary, not presentation.
- Disable offline cache restore for messages: rejected because the constitution and spec require offline-ready data flow.

## Decision 5: Replace placeholder diagnostics and tests with targeted behavior verification

**Decision**: Remove broad production `debugPrint`-style tracing from user-critical flows in favor of concise, maintainable diagnostics, and replace the placeholder widget smoke test with coverage for routing, cache restore, direct-chat launch behavior, and configuration validation.

**Rationale**: The repository currently has only `message_model_test.dart` plus a default counter-based widget smoke test that does not match the app. Stabilization work without regression coverage would lock in no contracts. The clarified feature explicitly requires operational confidence and reduced analyzer noise.

**Alternatives considered**:

- Keep the placeholder widget test and add only model tests: rejected because navigation/state regressions would remain unprotected.
- Add logging everywhere without structure: rejected because it increases noise and does not improve diagnosability sustainably.
- Postpone tests until after refactors land: rejected because this feature is explicitly about release readiness and regression prevention.
