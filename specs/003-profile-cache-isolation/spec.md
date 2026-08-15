# Изолировать Cached Profile по User Account и исправить update error flow

## Problem Statement

Пользователь ожидает, что его Profile останется приватным и что приложение
честно сообщит результат сохранения. Сейчас Cached Profile хранится под одним
глобальным ключом и не очищается при logout. После входа в другой User Account
клиент может кратко показать Profile предыдущего Messenger User до завершения
backend refresh.

Кроме того, ошибка `PATCH /profile` возвращает предыдущее состояние
`ProfileLoaded`. Экран воспринимает его как успешное обновление, закрывается и
показывает сообщение об успехе, хотя backend отклонил изменение. Это создаёт
риск раскрытия персональных данных и лишает пользователя достоверной обратной
связи.

## Solution

Cached Profile должен принадлежать конкретному User Account и никогда не
читаться для другого user ID. Logout должен удалить связанный cached snapshot,
а устаревший глобальный кеш неизвестного владельца нельзя показывать или
мигрировать как данные текущего пользователя.

Profile update должен иметь отдельные состояния progress, success и failure.
Экран редактирования закрывается и сообщает об успехе только после
подтверждённого server response. При ошибке он остаётся открытым, сохраняет
введённые значения и показывает понятную возможность повторить запрос.

## User Stories

1. As a signed-in user, I want Cached Profile to belong only to my User Account, so that another user of the device cannot see my personal data.
2. As a user switching accounts, I want the next account to ignore the previous account's Cached Profile, so that the settings screen never displays the wrong identity.
3. As a returning user, I want my own Cached Profile to appear while the backend refresh is in progress, so that profile loading remains responsive.
4. As a user who logs out, I want my cached personal data removed, so that it is not left available to the next session.
5. As a user with a legacy installation, I want an ownerless global profile cache to be discarded, so that old data is not attributed to the wrong User Account.
6. As a user whose Profile refresh succeeds, I want the server response to replace my cached snapshot, so that future loads show accepted values.
7. As a user whose Profile refresh fails after my own cache was shown, I want to keep seeing my cached values, so that a temporary network failure does not blank the screen.
8. As a user with no own Cached Profile and an unavailable backend, I want an explicit loading failure, so that missing data is not mistaken for an empty Profile.
9. As a user editing my Profile, I want a visible updating state, so that repeated submissions are prevented while the request is active.
10. As a user whose Profile update succeeds, I want the accepted server values displayed and cached, so that UI and local state match the backend.
11. As a user whose Profile update succeeds, I want the edit screen to close and show a success confirmation, so that the outcome is unambiguous.
12. As a user whose Profile update fails, I want the edit screen to remain open, so that I can correct or retry the request.
13. As a user whose Profile update fails, I want an error message instead of a success notification, so that the application does not misrepresent backend state.
14. As a user whose Profile update fails, I want my previously loaded Profile to remain available, so that the error does not erase confirmed data.
15. As a user retrying a failed update, I want my entered values preserved, so that I do not need to type them again.
16. As a user, I want only successful Profile responses written to Cached Profile, so that rejected edits cannot reappear after restart.
17. As a maintainer, I want cache ownership expressed through user ID rather than UI lifecycle, so that every Profile entry point follows the same privacy rule.
18. As a maintainer, I want update success and failure to be distinct public states, so that screens cannot infer operation outcome from a generic `ProfileLoaded` state.
19. As a maintainer, I want logout cache cleanup to be exercised through AuthBloc behavior, so that future authentication changes cannot silently reintroduce the leak.
20. As a maintainer, I want tests to assert observable BLoC and widget behavior rather than cache-key implementation details, so that the implementation remains refactorable.

## Implementation Decisions

- Introduce one Profile cache abstraction shared by Profile and authentication
  state flows. It owns serialization, user scoping, legacy cleanup and deletion.
- Address cached entries by the authenticated user ID. Profile code obtains that
  identity through the existing session/token abstraction rather than accepting
  an ID from widgets.
- Do not migrate the legacy global cached profile into a user-scoped entry: its
  owner cannot be proven. Delete or ignore it before the first scoped read.
- Logout clears the current User Account's Cached Profile before credentials are
  discarded. Cleanup failure must not restore or preserve an authenticated UI
  state, but it must be diagnosable.
- A cache read is allowed only when a non-empty authenticated user ID is
  available. Without one, Profile loading proceeds directly to backend or fails
  through the normal unauthenticated flow.
- A successful `GET /profile` response replaces only the current user's cached
  snapshot.
- A failed refresh may retain an already displayed cache belonging to the same
  user. It must never fall back to an entry owned by another account.
- Represent update progress, success and failure explicitly in Profile state.
  Returning a generic loaded state after an exception is prohibited.
- Update failure retains the last confirmed Profile separately from the error
  outcome so the UI can remain populated and retryable.
- The edit screen reacts to an explicit success outcome before navigating back.
  It stays open and presents an error for explicit failure.
- Only the accepted `PATCH /profile` response is written to Cached Profile.
  Submitted values are not considered confirmed data.
- Await cache writes and deletion at the application-state boundary so emitted
  success/logout states represent completed local lifecycle work.
- Keep the existing client-observed Profile API request and response shapes.
  This feature does not require a backend contract change.
- Use production-safe diagnostic context without logging Profile values,
  credentials or tokens.
- Update Product Baseline Known Deviations and the Auth/Profile client contract
  after behavior and tests are complete.

## Testing Decisions

- The primary seam is the public event/state boundary of ProfileBloc and
  AuthBloc using a shared in-memory Profile cache, fake session identity and
  controlled HTTP responses. Tests assert visible state and persisted ownership,
  not concrete SharedPreferences key strings.
- Add ProfileBloc behavior tests for own-cache-first load, account switching,
  ownerless legacy cache, successful refresh, failed refresh with own cache and
  failed refresh without cache.
- Add Profile update tests for progress, explicit success, explicit failure,
  retention of the last confirmed Profile, retry, and writing cache only after
  success.
- Add AuthBloc logout coverage proving that cached Profile data is removed for
  the current User Account while the session still becomes unauthenticated.
- Add one widget test at the edit-screen seam: success closes the screen and
  reports success; failure keeps it open, preserves input and reports an error.
- Include an account-switch regression scenario: load account A, logout, sign in
  as account B while profile networking is delayed, and assert that A's Profile
  is never emitted or rendered.
- Follow the repository's existing BLoC unit-test style with controlled Dio
  interceptors and explicit emitted-state expectations. Do not repeat static
  source-string assertions used by the current route test.
- Tests must cover failure and privacy behavior, not only the happy path.
- Run the complete `flutter test` suite and `flutter analyze` after the new
  focused tests pass.

## Out of Scope

- Validating access-token expiry during application startup.
- Changing signin, signup, refresh or logout backend endpoints.
- Server-side session revocation.
- Adding Profile fields, avatar editing or presence synchronization.
- Offline Profile editing or queued update requests.
- Encrypting general SharedPreferences data or replacing the storage package.
- Changing Chat, Message, Attachment or contact caching.
- Fixing other Product Baseline Known Deviations.
- Changing Runtime Environment source precedence.
- Adding a new state-management framework.

## Further Notes

- Product terminology follows the root `CONTEXT.md`: User Account owns an
  Authenticated Session, while Profile and Cached Profile describe personal
  display data for a Messenger User.
- The current Auth/Profile Integration Contract is client-observed and still
  requires backend verification; this change preserves its request/response
  expectations.
- The existing Product Baseline remains `Draft`. After implementation, remove or
  revise the Profile cache and false-success Known Deviations and add the new
  verification evidence.
- No ADR is required: user-scoping sensitive cached data and exposing honest
  operation outcomes are reversible local design choices without technology
  lock-in.

## Verification Evidence

- `flutter test`: 26 tests passed, including focused ProfileBloc, AuthBloc and
  edit Profile widget coverage.
- `flutter analyze`: no issues found.
- Account-switch regression confirms that a delayed response for User Account A
  is neither emitted nor cached after the session changes to User Account B.
