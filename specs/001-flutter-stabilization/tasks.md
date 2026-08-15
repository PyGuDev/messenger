# Tasks: Flutter Stabilization Plan

**Input**: Design documents from `/specs/001-flutter-stabilization/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for this feature because it changes business logic, navigation, state handling, persistence, and documented integrations.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g. `US1`, `US2`, `US3`)
- Include exact file paths in descriptions

## Path Conventions

- Flutter client code lives under `lib/`
- Automated tests live under `test/`
- Contract and contributor documentation lives under `docs/` and `README.md`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Align the implementation surface, test entry points, and documentation targets before feature work starts.

- [X] T001 Audit the current stabilization touch points in `lib/main.dart`, `lib/core/di/injection_container.dart`, `lib/core/network/network_module.dart`, `lib/core/navigation/router.dart`, `lib/features/messages/`, `lib/features/chats/`, and `lib/features/contacts/`
- [X] T002 [P] Create or reserve regression test files for this slice in `test/features/messages/messages_bloc_test.dart`, `test/features/messages/messages_local_data_source_test.dart`, `test/features/chats/contact_chat_launch_bloc_test.dart`, `test/core/network/runtime_environment_test.dart`, and `test/navigation/chat_route_test.dart`
- [X] T003 [P] Identify contributor-facing docs that must remain synchronized in `README.md`, `docs/chat_api.md`, and `docs/FRONTEND_API_GUIDE.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish shared infrastructure required by every story before feature-specific work begins.

**⚠️ CRITICAL**: No user story work should begin until this phase is complete.

- [X] T004 Implement the runtime environment profile and configuration error models in `lib/core/network/runtime_environment_profile.dart` and `lib/core/network/configuration_error_state.dart`
- [X] T005 [P] Refactor startup configuration resolution and DI registration in `lib/core/network/network_module.dart`, `lib/core/di/injection_container.dart`, and `lib/main.dart` to create one validated environment profile before network clients are used
- [X] T006 [P] Add shared diagnostics/error handling primitives for blocking configuration failures and session-level logging in `lib/core/network/network_module.dart`, `lib/core/network/websocket_service.dart`, and `lib/core/network/auth_interceptor.dart`
- [X] T007 Create route/session wiring for chat-scoped dependencies in `lib/core/navigation/router.dart`, `lib/main.dart`, and `lib/core/di/injection_container.dart`

**Checkpoint**: Foundation ready. User story work can proceed in priority order, and some story tasks can run in parallel once T004-T007 are complete.

---

## Phase 3: User Story 1 - Trust Message History (Priority: P1) 🎯 MVP

**Goal**: Restore and reconcile each chat timeline deterministically, with message/media state isolated to the active chat session.

**Independent Test**: Open a previously synced chat, disconnect, reopen it, and confirm the same chat-specific timeline appears; then switch chats and verify no messages, media state, or drafts leak across sessions.

### Tests for User Story 1

- [X] T008 [P] [US1] Add cache serialization and reconciliation regression coverage in `test/features/messages/messages_local_data_source_test.dart`
- [X] T009 [P] [US1] Add `MessagesBloc` offline restore, first-sync offline unavailable, and cross-chat isolation coverage in `test/features/messages/messages_bloc_test.dart`
- [X] T010 [P] [US1] Add route-scoped chat session lifecycle coverage in `test/navigation/chat_route_test.dart`

### Implementation for User Story 1

- [X] T011 [P] [US1] Canonicalize message and attachment persistence shape in `lib/features/messages/data/models/message_model.dart` and `lib/features/messages/data/datasources/messages_local_data_source.dart`
- [X] T012 [US1] Update message cache reads/writes and merge rules to enforce chat ownership and deterministic restore in `lib/features/messages/data/datasources/messages_local_data_source.dart` and `lib/features/messages/presentation/bloc/messages_bloc.dart`
- [ ] T013 [US1] Refactor `MessagesBloc` session state and teardown behavior for active-chat ownership in `lib/features/messages/presentation/bloc/messages_bloc.dart` and `lib/features/messages/presentation/bloc/messages_state.dart`
- [X] T014 [US1] Scope chat loading and retry flows to the route-bound session in `lib/features/messages/presentation/screens/messages_screen.dart` and `lib/core/navigation/router.dart`
- [ ] T015 [US1] Reset or dispose draft, media, and camera-related state on chat exit/switch in `lib/features/messages/presentation/screens/messages_screen.dart`, `lib/core/network/camera_service.dart`, and `lib/core/network/websocket_service.dart`
- [ ] T016 [US1] Add the offline-unavailable UX state and localized copy for first-sync failures in `lib/features/messages/presentation/screens/messages_screen.dart` and `lib/l10n/`
- [ ] T017 [US1] Update chat session behavior documentation for cache restore and per-chat state ownership in `specs/001-flutter-stabilization/contracts/chat-session-behavior.md` and `docs/chat_api.md`

**Checkpoint**: User Story 1 is independently functional when cached restore, refresh reconciliation, and session isolation all pass without cross-chat leakage.

---

## Phase 4: User Story 2 - Start Conversations Predictably (Priority: P2)

**Goal**: Move contact-to-chat launch into application-controlled state so existing direct chats are reused and failed launches remain recoverable.

**Independent Test**: Open a contact profile, trigger conversation launch for a contact with and without an existing direct chat, and verify the app reuses or creates the correct chat while repeated taps collapse to one outcome.

### Tests for User Story 2

- [X] T018 [P] [US2] Add direct-chat launch state transition and duplicate-request coverage in `test/features/chats/contact_chat_launch_bloc_test.dart`
- [ ] T019 [P] [US2] Add navigation flow coverage for contact-profile-to-chat resolution in `test/navigation/chat_route_test.dart`

### Implementation for User Story 2

- [X] T020 [P] [US2] Add conversation launch events, states, and orchestration logic in `lib/features/chats/presentation/bloc/contact_chat_launch_bloc.dart` and `lib/features/chats/presentation/bloc/chats_bloc.dart`
- [X] T021 [US2] Move direct-chat lookup/create orchestration out of widget code and into application state in `lib/features/contacts/presentation/screens/contact_profile_screen.dart` and `lib/features/chats/presentation/bloc/contact_chat_launch_bloc.dart`
- [X] T022 [US2] Wire canonical contact-to-chat navigation outcomes through the router in `lib/core/navigation/router.dart` and `lib/features/contacts/presentation/screens/contact_profile_screen.dart`
- [X] T023 [US2] Handle in-flight retries, recoverable errors, and progress UI for conversation launch in `lib/features/contacts/presentation/screens/contact_profile_screen.dart` and `lib/features/chats/presentation/bloc/contact_chat_launch_bloc.dart`
- [X] T024 [US2] Synchronize the direct-chat reuse/create contract in `specs/001-flutter-stabilization/contracts/chat-session-behavior.md` and `docs/chat_api.md`

**Checkpoint**: User Story 2 is independently functional when contact entry points consistently reuse existing direct chats, create only when needed, and never navigate into a partial failure state.

---

## Phase 5: User Story 3 - Ship With Operational Confidence (Priority: P3)

**Goal**: Make deployment configuration explicit and validated, reduce noisy production diagnostics, and replace placeholder coverage with release-relevant regression tests.

**Independent Test**: Start the app with valid and invalid environment profiles, run `flutter analyze` and `flutter test`, and confirm blocking configuration failures happen before network calls while automated coverage protects critical routing, cache, and state behavior.

### Tests for User Story 3

- [X] T025 [P] [US3] Add runtime environment validation and blocking configuration error coverage in `test/core/network/runtime_environment_test.dart`
- [ ] T026 [P] [US3] Replace the placeholder smoke test with messaging- and navigation-relevant coverage in `test/widget_test.dart` and `test/navigation/chat_route_test.dart`

### Implementation for User Story 3

- [X] T027 [P] [US3] Remove hardcoded endpoint usage from transport clients and consume the validated environment profile in `lib/core/network/network_module.dart`, `lib/core/network/websocket_service.dart`, and `lib/core/network/file_service.dart`
- [X] T028 [US3] Surface a blocking configuration error state before affected network flows begin in `lib/main.dart`, `lib/core/navigation/router.dart`, and `lib/core/network/network_module.dart`
- [X] T029 [US3] Replace scattered debug logging with concise production-safe diagnostics in `lib/core/network/user_service.dart`, `lib/core/network/websocket_service.dart`, `lib/core/network/auth_interceptor.dart`, `lib/features/messages/presentation/bloc/messages_bloc.dart`, and `lib/features/contacts/presentation/screens/contact_profile_screen.dart`
- [X] T030 [US3] Update contributor environment setup and verification guidance in `README.md`, `docs/FRONTEND_API_GUIDE.md`, and `specs/001-flutter-stabilization/contracts/runtime-config.md`

**Checkpoint**: User Story 3 is independently functional when startup blocks invalid configuration early, diagnostics are actionable without noisy debug traces, and regression coverage protects the stabilization surface.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup across all implemented stories.

- [ ] T031 [P] Run the full stabilization verification flow from `specs/001-flutter-stabilization/quickstart.md`
- [X] T032 Fix analyzer warnings and cleanup remaining stabilization-related issues in `lib/` and `test/` surfaced by `flutter analyze`
- [ ] T033 [P] Confirm final contract and contributor documentation alignment in `README.md`, `docs/chat_api.md`, and `docs/FRONTEND_API_GUIDE.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup and blocks all user stories.
- **User Story 1 (Phase 3)**: Starts after Foundational and is the MVP slice.
- **User Story 2 (Phase 4)**: Starts after Foundational; may reuse the route/session wiring from US1 but remains independently testable.
- **User Story 3 (Phase 5)**: Starts after Foundational; can run in parallel with later US1 or US2 tasks where files do not overlap.
- **Polish (Phase 6)**: Starts after the desired user stories are complete.

### User Story Dependencies

- **US1**: No dependency on other user stories after Phase 2.
- **US2**: No functional dependency on US1, but shares router and navigation surfaces, so merge carefully if implemented in parallel.
- **US3**: No functional dependency on US1 or US2, but it touches startup/network infrastructure used by both.

### Within Each User Story

- Tests should be written or updated before the corresponding implementation tasks when practical.
- Persistence/model changes should land before BLoC/session behavior that consumes them.
- State-flow and router changes should land before widget/UI cleanup that depends on those flows.
- Documentation changes should ship in the same story phase as the behavior they describe.

### Parallel Opportunities

- `T002` and `T003` can run in parallel during setup.
- `T005` and `T006` can run in parallel after `T004`.
- In US1, `T008`, `T009`, `T010`, and `T011` can run in parallel.
- In US2, `T018`, `T019`, and `T020` can run in parallel.
- In US3, `T025`, `T026`, and `T027` can run in parallel.
- `T031` and `T033` can run in parallel during polish.

---

## Parallel Example: User Story 1

```bash
# Launch US1 regression coverage work together:
Task: "Add cache serialization and reconciliation regression coverage in test/features/messages/messages_local_data_source_test.dart"
Task: "Add MessagesBloc offline restore, first-sync offline unavailable, and cross-chat isolation coverage in test/features/messages/messages_bloc_test.dart"
Task: "Add route-scoped chat session lifecycle coverage in test/navigation/chat_route_test.dart"

# Launch US1 model/session implementation work together:
Task: "Canonicalize message and attachment persistence shape in lib/features/messages/data/models/message_model.dart and lib/features/messages/data/datasources/messages_local_data_source.dart"
Task: "Refactor MessagesBloc session state and teardown behavior for active-chat ownership in lib/features/messages/presentation/bloc/messages_bloc.dart and lib/features/messages/presentation/bloc/messages_state.dart"
```

---

## Parallel Example: User Story 2

```bash
# Launch US2 test and state scaffolding together:
Task: "Add direct-chat launch state transition and duplicate-request coverage in test/features/chats/contact_chat_launch_bloc_test.dart"
Task: "Add navigation flow coverage for contact-profile-to-chat resolution in test/navigation/chat_route_test.dart"
Task: "Add conversation launch events, states, and orchestration logic in lib/features/chats/presentation/bloc/contact_chat_launch_bloc.dart and lib/features/chats/presentation/bloc/chats_bloc.dart"
```

---

## Parallel Example: User Story 3

```bash
# Launch US3 validation and infrastructure work together:
Task: "Add runtime environment validation and blocking configuration error coverage in test/core/network/runtime_environment_test.dart"
Task: "Replace the placeholder smoke test with messaging- and navigation-relevant coverage in test/widget_test.dart and test/navigation/chat_route_test.dart"
Task: "Remove hardcoded endpoint usage from transport clients and consume the validated environment profile in lib/core/network/network_module.dart, lib/core/network/websocket_service.dart, and lib/core/network/file_service.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: User Story 1.
4. Validate cached restore, offline-unavailable handling, and chat-session isolation before moving on.

### Incremental Delivery

1. Finish Setup + Foundational to stabilize startup, DI, and route ownership.
2. Deliver US1 as the first releasable stabilization slice.
3. Deliver US2 once contact-to-chat flow is owned by application state.
4. Deliver US3 to lock in deploy-time configuration and release-readiness verification.

### Parallel Team Strategy

1. One developer handles Phase 2 environment/bootstrap work while another prepares the test files from Phase 1.
2. After Phase 2, assign US1, US2, and US3 to separate developers, coordinating carefully on `lib/core/navigation/router.dart`, `lib/main.dart`, and `lib/core/network/network_module.dart`.
3. Rejoin for Phase 6 validation and documentation synchronization.

---

## Notes

- All tasks use the required checklist format with sequential task IDs, explicit story labels where needed, and concrete file paths.
- Tests are included in every user story because each story changes observable behavior and documented contracts.
- `docs/chat_api.md`, `docs/FRONTEND_API_GUIDE.md`, and `README.md` stay coupled to the behavior they describe; do not defer those updates to a later unrelated change.
- Reconciled against the working tree on 2026-08-16. `flutter test` passed 38 tests and `flutter analyze` reported no issues.
- T013, T015, T016, T017, T019, and T026 remain unchecked because their implementation or behavioral coverage is partial. T010 now covers creation and disposal of route-scoped `MessagesBloc` instances; voice recording teardown remains incomplete, offline copy is not localized, and pagination/full session-switch journeys still lack coverage.
- T031 remains open because the manual quickstart journeys were not executed. T033 remains open while runtime source precedence differs from the target contract and final backend contract verification is pending.
