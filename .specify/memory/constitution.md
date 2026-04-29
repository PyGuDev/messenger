<!--
Sync Impact Report
- Version change: template -> 1.0.0
- Modified principles:
  - Template principle 1 -> I. Feature-First Layering
  - Template principle 2 -> II. Predictable State Through BLoC
  - Template principle 3 -> III. Offline-Ready Data Flow
  - Template principle 4 -> IV. Contract-Driven Integrations
  - Template principle 5 -> V. Testable Vertical Slices
- Added sections:
  - Engineering Constraints
  - Delivery Workflow
- Removed sections:
  - None
- Templates requiring updates:
  - ✅ updated .specify/templates/plan-template.md
  - ✅ updated .specify/templates/spec-template.md
  - ✅ updated .specify/templates/tasks-template.md
  - ✅ updated README.md
  - ⚠ pending .specify/templates/commands/*.md (directory not present in this repository)
- Follow-up TODOs:
  - None
-->
# Messenger Constitution

## Core Principles

### I. Feature-First Layering
All product work MUST live in a feature-first structure under `lib/features/<feature>`
with explicit `presentation`, `data`, and shared/core boundaries. Presentation code
MUST depend on abstractions and models exposed by its feature or shared core modules;
it MUST NOT reach directly into unrelated features. Shared utilities belong in `lib/core`
or `lib/shared` only when at least two features use them. Rationale: the repository is
already organized by feature, and preserving those boundaries keeps growth manageable.

### II. Predictable State Through BLoC
User-visible state transitions MUST flow through BLoC or an equally explicit event/state
abstraction already accepted by the codebase. Screens and widgets MUST stay thin: they
dispatch intents, render state, and avoid embedding business rules, networking, or
persistence logic. Dependency wiring MUST remain centralized in the DI container so that
features can be instantiated consistently in tests and at runtime. Rationale: predictable
state flow is the main guardrail against regressions in a multi-screen messenger app.

### III. Offline-Ready Data Flow
Features that read or mutate chats, messages, contacts, or profile data MUST define how
local persistence, cache invalidation, and network recovery behave before implementation
starts. Local storage is the default source for restoring user context, and remote sync
MUST be resilient to retries, temporary disconnects, and duplicate deliveries. Any new
network path MUST specify its failure states and user-facing fallback behavior. Rationale:
messaging UX degrades quickly when data loss or inconsistent local state is tolerated.

### IV. Contract-Driven Integrations
Any change that touches backend APIs, WebSocket payloads, file transfer flows, or auth
semantics MUST update the relevant contract documentation in `docs/` within the same
change. Implementations MUST follow documented request/response envelopes, auth rules,
and error models, or the spec/plan MUST call out the intended contract delta explicitly.
Rationale: this codebase already depends on documented chat and file-service APIs, and
drift between client code and docs is a direct delivery risk.

### V. Testable Vertical Slices
Every feature increment MUST be deliverable as an independently testable vertical slice.
Code changes that alter business logic, navigation, persistence, or integrations MUST add
or update automated tests at the appropriate level (`test/` and higher-scope verification
when needed). A task plan is incomplete unless it includes validation for the primary user
journey, error handling, and contract-sensitive behavior. Rationale: the project needs
working increments, not broad refactors with deferred verification.

## Engineering Constraints

The primary stack is Flutter on Dart 3 with mobile and web targets. New architecture work
MUST preserve compatibility with the existing stack: Flutter widgets in `lib/`, BLoC for
state coordination, `dio` and WebSocket-based networking, local persistence via current
storage choices such as `sqflite`, secure token handling, and generated localizations in
`lib/l10n`. Experimental frameworks, duplicate state managers, or feature-local ad hoc
network clients MUST NOT be introduced without an explicit complexity justification in the
implementation plan.

API-facing work MUST document required environment details, auth assumptions, payload
shapes, and rollback behavior. UI work MUST account for Russian and English localization,
responsive layouts, and failure states for empty, loading, and error conditions.

## Delivery Workflow

Specifications MUST describe user stories as independently valuable slices and record any
affected contracts, local storage expectations, and offline/error behavior. Plans MUST
pass the Constitution Check before design starts and again before implementation begins.
Tasks MUST remain organized by user story, include exact file paths, and explicitly cover
tests and documentation updates for each contract-sensitive change.

Reviews MUST verify boundary integrity, BLoC-centered state transitions, local/remote data
consistency, API doc synchronization, and automated test coverage for changed behavior.
When a change cannot satisfy a principle, the plan MUST document the violation, justify
why it is necessary now, and name the simpler alternative that was rejected.

## Governance

This constitution overrides conflicting local habits and templates for the Messenger
project. Amendments require: (1) a documented change to this file, (2) synchronization of
affected templates or guidance docs, and (3) a semantic version update justified by the
scope of governance change. Versioning policy is strict SemVer for the constitution:
MAJOR for incompatible principle removals or redefinitions, MINOR for new principles or
materially expanded governance, PATCH for clarifications that do not change expectations.

Every implementation plan, specification, and task list MUST include a compliance review
against these principles. Pull requests and manual reviews MUST block changes that violate
the constitution without an explicit, documented exception in the plan. Runtime guidance
in `README.md` and integration guidance in `docs/` remain subordinate to this file and
must be kept aligned when the constitution changes.

**Version**: 1.0.0 | **Ratified**: 2026-04-22 | **Last Amended**: 2026-04-22
