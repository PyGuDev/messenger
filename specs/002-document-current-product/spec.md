# Product Baseline: текущая реализация Messenger

**Feature Branch**: `002-document-current-product`

**Создан**: 2026-08-15

**Проверен по commit**: 2026-08-16

**Verification Commit**: `79a2718ee43c0b9d0beb7e5c3bec63ab2d29e4e2`

**Status**: Draft

**Input**: «Подготовить спецификацию для текущей реализации»

## Назначение и границы

Документ фиксирует доступное пользователю поведение текущего Flutter-клиента.
Это Product Baseline для будущих проверок и планирования, а не предложение
новой функциональности. Утверждение включается сюда только если путь доступен
из UI и подтверждается кодом, а для статуса `Verified` — ещё автоматическим
тестом либо воспроизводимым manual-сценарием.

Production changes, обследованные для этого baseline, относятся к
[Flutter Stabilization Plan 001](../001-flutter-stabilization/spec.md), а не к
требованиям этого baseline. Они проверены по Feature Specification 001 и
зафиксированы отдельным Verification Commit.

Baseline описывает указанный Verification Commit. Он остаётся `Draft`, пока не
выполнены все Success Criteria и manual journeys. Известные расхождения между
намерением и реализацией перечислены в разделе
[Known Deviations](#known-deviations).

## Constitution Compliance

- **I. Feature-First Layering**: baseline не вводит новую product-реализацию и
  фиксирует существующие feature/shared/core boundaries; production-изменения
  проверены отдельно в рамках Flutter Stabilization 001.
- **II. Predictable State Through BLoC**: пользовательские состояния и известные
  отклонения описаны по фактическим BLoC и UI flows; исправления границ state
  management не выдаются за требования этого документа.
- **III. Offline-Ready Data Flow**: для Chats, Messages и Profile зафиксированы
  источники кеша, remote refresh, recovery и неоднозначные offline/error states.
- **IV. Contract-Driven Integrations**: Chat, File, Auth и Profile contracts
  связаны с baseline; client-observed Auth/Profile contract явно не считается
  подтверждённым backend-контрактом.
- **V. Testable Vertical Slices**: Verification Record привязан к commit и
  автоматическим проверкам, а недостающие journeys и failure-path проверки
  оставляют документ в статусе `Draft` до выполнения Success Criteria.

Исключений из принципов Конституции для этого Product Baseline нет.

## Пользовательские сценарии

### User Story 1 — Доступ к User Account (P1)

Пользователь может зарегистрироваться, войти, восстановить локально сохранённую
сессию и выйти из неё.

**Проверяемый сценарий**: зарегистрироваться или войти, перезапустить клиент,
проверить маршрутизацию по сохранённому access token, затем выполнить logout.

**Текущее поведение**:

1. Без сохранённого access token клиент открывает welcome/auth flow.
2. Регистрация принимает имя, фамилию, email, российский номер телефона,
   password и confirmation.
3. После signin/signup клиент сохраняет access token, refresh token и user ID.
4. При старте наличие access token считается достаточным для восстановления
   Authenticated Session; срок действия проверяется только после ответа `401`.
5. При `401` клиент пытается обновить токены и повторить исходный запрос.
6. Logout очищает локальные credentials и отключает Realtime Connection;
   серверный logout endpoint не вызывается.

### User Story 2 — Обмен Messages (P1)

Пользователь может открыть Chat, видеть локально сохранённую историю, отправлять
текст и поддерживаемые Attachments, отвечать на Message и получать realtime
обновления.

**Проверяемый сценарий**: открыть Chat, загрузить историю, отправить каждый
поддерживаемый вид Message, выполнить reply, получить входящий Message и снова
открыть Chat без сети.

**Текущее поведение**:

1. При открытии Chat клиент сначала читает его Message Timeline Cache, затем при
   наличии сети запрашивает последние 50 Messages.
2. Более ранняя история загружается постранично при достижении границы списка.
3. Текстовый Message сразу появляется со статусом `sending`, затем может стать
   `sent`, `delivered`, `read` или `failed`.
4. Для failed text Message доступен retry с тем же client message ID. UI также
   показывает retry для failed Attachments, но этот путь работает некорректно и
   перечислен в Known Deviations.
5. Reply reference поддерживается для исходящих текстовых и медиа Messages.
6. Клиент поддерживает image, document, voice recording и video recording при
   наличии разрешений и возможностей устройства.
7. Активный Chat обрабатывает `new_message`, `message_read` и
   `message_status_changed`. Chat list обрабатывает `new_message` и
   `message_read`.
8. При отсутствии сети непустой кеш показывается для соответствующего Chat.
   Если remote history refresh завершается любой ошибкой и кеш пуст, клиент
   показывает `offline unavailable` независимо от наличия Network Connectivity
   и фактической причины ошибки.

### User Story 3 — Поиск и запуск Chats (P2)

Пользователь может просматривать Matched Contacts и Chats, запускать Direct Chat
и отправлять запрос на создание Group Chat.

**Проверяемый сценарий**: разрешить доступ к контактам, открыть существующий
Direct Chat, запустить новый Direct Chat и отправить создание именованного
Group Chat хотя бы с одним участником.

**Текущее поведение**:

1. Device Contacts с телефонами сопоставляются с Messenger Users и доступны для
   поиска по имени без учёта регистра.
2. При выборе Matched Contact клиент ищет существующий Direct Chat и создаёт
   новый только при ответе not found.
3. Повторные нажатия в рамках одного активного launch flow схлопываются до
   одного клиентского запроса.
4. Создание Group Chat разрешено при непустом title и хотя бы одном выбранном
   участнике; экран закрывается сразу после отправки события создания.
5. Chat list сначала может показать кешированные summaries, затем обновляет их
   с сервера.
6. Следующая страница Chats добавляется к уже показанному списку.

### User Story 4 — Device Contacts и Profile (P3)

Пользователь может добавить Device Contact, открыть свой Profile и изменить
отображаемые поля.

**Проверяемый сценарий**: создать Device Contact, обновить список, открыть
settings, изменить каждое редактируемое поле Profile и проверить результат
успешного server response.

**Текущее поведение**:

1. При наличии permission Device Contact сохраняется в адресную книгу, после
   чего список перечитывается.
2. Settings может сначала показать Cached Profile только текущего User Account,
   затем заменить его ответом `GET /profile`; ownerless legacy cache не
   показывается и не мигрируется.
3. При сохранении edit screen передаёт в `PATCH /profile` текущие значения всех
   четырёх полей — first name, last name, phone и email — даже если изменена
   только часть из них. Только успешный response отображается и кешируется. При
   ошибке edit screen остаётся открытым, сохраняет ввод и показывает error.
4. Logout удаляет Cached Profile текущего User Account до очистки credentials.
5. При потере Network Connectivity основная область показывает постоянный
   offline banner.

## Edge Cases

- Runtime Environment Profile отсутствует или содержит некорректные URL.
- Access token отсутствует, истёк или не может быть обновлён.
- Permission контактов отклонён или Device Contact не содержит телефона.
- Device Contact не соответствует Messenger User.
- Поиск Direct Chat возвращает not found, transport error или ответ без chat ID.
- Кешированные Chats или Messages существуют при недоступном backend.
- Пользователь меняет Chat во время load, записи или подготовки Attachment.
- Upload, recording, download или открытие Attachment завершается ошибкой.
- Realtime Connection отключается и позднее восстанавливается.
- Один Message или receipt приходит повторно.

## Functional Requirements текущей реализации

- **FR-001**: Клиент валидирует обязательные service URLs до запуска сетевых
  сценариев и показывает blocking Configuration Error при ошибке.
- **FR-002**: Клиент предоставляет signup с first name, last name, email, phone,
  password и confirmation.
- **FR-003**: Клиент предоставляет signin, восстановление по наличию сохранённого
  access token, refresh после `401`, protected routing и локальный logout.
- **FR-004**: Credentials сохраняются через platform secure storage; на macOS
  при ошибке Keychain клиент переключается на SharedPreferences fallback.
- **FR-005**: Главная область содержит Contacts, Chats, Calls и Settings и по
  умолчанию открывается на Chats.
- **FR-006**: Calls tab сообщает, что звонки недоступны в текущей версии.
- **FR-007**: Клиент запрашивает contact permission, читает Device Contacts с
  телефонами, выполняет matching и поиск по Matched Contacts.
- **FR-008**: Клиент позволяет создать Device Contact и перечитать список.
- **FR-009**: Contact launch ищет существующий Direct Chat либо отправляет
  создание нового; одновременные повторы в одном flow блокируются.
- **FR-010**: Group Chat request требует title и хотя бы одного участника.
- **FR-011**: Chat list показывает title, latest-message preview, time и unread
  count, использует кешированный fallback и поддерживает pagination.
- **FR-012**: Для каждого route Chat создаётся отдельный MessagesBloc и
  screen-local state; camera и voice recording services создаются и
  освобождаются в границах Chat Session.
- **FR-013**: Непустой Message Timeline Cache восстанавливается по chat ID;
  любой неуспешный history refresh при пустом кеше приводит к
  `MessagesOfflineUnavailable`, включая backend и parsing errors при наличии
  сети.
- **FR-014**: History pagination добавляет полученную страницу к ленте; текущая
  реализация не устраняет пересечения между страницами.
- **FR-015**: Text sending использует optimistic Message, client message ID,
  видимый статус и ручной retry.
- **FR-016**: Клиент поддерживает reply на видимый Message и ввод emoji.
- **FR-017**: Клиент поддерживает image/document selection, voice recording и
  video recording при наличии device capability и permission.
- **FR-018**: Поддерживаемые Attachments можно preview, download, cache или open
  в зависимости от вида.
- **FR-019**: Активный Chat и Chat list применяют поддерживаемое ими подмножество
  realtime events.
- **FR-020**: Экран Chat отправляет mark-read request; unread count Chat list
  обновляется при соответствующем realtime event.
- **FR-021**: Клиент кеширует Chat summaries, Messages, Profile snapshot по
  User Account и загруженные Attachments с ограничениями из Known Deviations.
- **FR-022**: Реализованы loading, error, empty и offline states; отказ contact
  permission и отсутствие Matched Contacts отображаются как отдельные
  localized состояния.
- **FR-023**: Profile позволяет изменять first name, last name, phone и email и
  при каждом сохранении отправляет текущие значения всех четырёх полей.
- **FR-024**: Клиент показывает потерю Network Connectivity и пытается
  восстановить Realtime Connection после её возвращения.
- **FR-025**: Chat и file flows ориентируются на документы в `docs/`; Auth и
  Profile пока описаны только client-observed контрактом.

## Ключевые сущности

Канонические определения находятся в [CONTEXT.md](../../CONTEXT.md):

- User Account, Authenticated Session, Messenger User;
- Device Contact, Matched Contact, Profile, Cached Profile;
- Chat, Direct Chat, Group Chat, Chat Session;
- Message, Message Delivery State, Message Timeline Cache;
- Attachment и Attachment Access State;
- Network Connectivity, Realtime Connection, Offline Capability;
- Runtime Environment Profile.

## Текущие границы продукта

- Voice и video calls не реализованы; Calls tab является placeholder.
- Call/video controls в Chat и Contact Profile выглядят активными, но имеют
  пустые callbacks.
- Выбор фотографии Device Contact не реализован, хотя affordance отображается.
- Основной список Contacts показывает только Matched Contacts.
- Edit, delete и forward Messages не доступны как действия текущего Chat UI.
- Password recovery, account deletion, contact editing и presence sync не входят
  в видимый flow.
- Ресурсы локализации для English и Russian существуют, однако часть текста
  hard-coded.
- Offline Capability ограничена чтением кеша; automatic offline send queue нет.

## Known Deviations

1. При старте любой сохранённый access token считается Authenticated Session;
   срок действия не проверяется до первого `401`.
2. Нет persisted successful-sync marker. Никогда не синхронизированный Chat и
   успешно синхронизированный пустой Chat неразличимы offline.
3. `MessagesOfflineUnavailable` объединяет отсутствие сети с backend, parsing и
   другими ошибками history refresh при пустом кеше, поэтому состояние может
   ошибочно сообщать пользователю о проблеме с подключением.
4. History pagination добавляет страницу без reconciliation, поэтому пересечение
   страниц может показать duplicate Messages.
5. Realtime duplicate delivery не устраняется перед добавлением Message в
   видимую ленту.
6. Успешный history refresh полностью заменяет строки Chat серверной страницей и
   может удалить локальные `sending`/`failed` Messages.
7. Успешный retry обновляет UI, но не гарантирует замену cached failed Message
   серверной версией после restart.
8. UI показывает retry для любого собственного failed Message, включая
   Attachment, но `ResendMessage` всегда отправляет только текстовый `body` в
   messages endpoint. Retry медиа может отправить пустой текст вместо исходного
   Attachment.
9. Group Chat screen закрывается до результата создания и не показывает ошибку
   создания на исходном экране.
10. Chat list не обрабатывает `message_status_changed`, а mark-read влияет на его
    unread count только после соответствующего realtime event.
11. Direct Chat lookup/create не является атомарной server-side операцией;
    client-side защита блокирует повторы только внутри одного launch flow.
12. Call/video controls вне Calls tab выглядят доступными, хотя ничего не делают.

## Verification Record

Проверка 2026-08-16 по Verification Commit:

- `flutter test`: 42 tests passed;
- `flutter analyze`: no issues found;
- автоматизированы Runtime Environment validation, blocking configuration UI,
  cache serialization/reconciliation, empty-cache offline state,
  ContactChatLaunchBloc, Matched Contacts application state и localized
  loading/error/empty states, Profile cache/update, Auth logout, edit Profile UI
  lifecycle route-scoped `MessagesBloc`, Chat Session media teardown и
  localized first-sync offline-unavailable UX;
- отсутствуют полноценные automated journeys для оставшихся auth, group
  creation, media lifecycle, realtime, pagination и полного switch Chat со
  сбросом reply/recording/Attachment state.

## Success Criteria для перехода в Verified

- **SC-001**: Четыре основные journeys — account access, messaging, chat
  discovery и profile/contact management — воспроизводимо проходят на commit,
  указанном в metadata.
- **SC-002**: Widget/integration test подтверждает отсутствие timeline, reply,
  recording и Attachment leakage при switch Chat.
- **SC-003**: Реализация хранит successful-sync marker и различает пустой
  синхронизированный Chat и never-synchronized Chat offline.
- **SC-004**: Повторный запуск Direct Chat приводит к одному каноническому Chat
  при подтверждённых server semantics.
- **SC-005**: Каждый поддерживаемый исходящий Message получает успешное либо
  явное failed состояние; retry корректно обновляет UI и cache.
- **SC-006**: Invalid Runtime Environment блокируется до первого затронутого
  network request.
- **SC-007**: Неактивные возможности отсутствуют из actionable flow либо явно
  отображаются как unavailable.

Эти критерии являются gate для будущего статуса `Verified`, а не заявлением о
том, что результат уже достигнут.

## Предположения и происхождение контрактов

- Документ описывает commit `79a2718ee43c0b9d0beb7e5c3bec63ab2d29e4e2`
  ветки `002-document-current-product`, проверенный 2026-08-16.
- [Chat Service API](../../docs/chat_api.md) и
  [File Service API](../../docs/FRONTEND_API_GUIDE.md) считаются серверными
  Integration Contracts, но требуют периодической сверки с backend.
- [Auth and Profile Client Contract](../../docs/auth_api.md) описывает только
  ожидания клиента и требует backend verification.
- Direct Chat содержит двух Messenger Users; Group Chat содержит creator и
  одного или нескольких выбранных участников.
- Dormant handlers без доступного UI entry point не считаются текущей
  пользовательской возможностью.

## Влияние на документацию

- После устранения Known Deviations baseline следует повторно проверить,
  привязать к Git commit и перевести в `Verified`.
- Изменения текущего поведения должны обновлять этот baseline либо заменять его
  новой версией после реализации соответствующей Feature Specification.
- Runtime setup остаётся в `README.md`, а полный индекс — в `docs/README.md`.
