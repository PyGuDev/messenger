# Messenger

Продуктовый контекст Messenger охватывает доступ к User Account, контакты,
Chats, Messages, Attachments, Profile и поведение при изменении соединения.

## Язык документации

**Product Baseline**:
Проверенное пользовательское поведение текущей версии продукта. Содержит только поведение, подтверждённое реализацией.
_Avoid_: Текущий план, целевая спецификация

**Feature Specification**:
Ограниченное описание предлагаемого или изменяемого поведения, отделённое от Product Baseline до реализации и проверки.
_Avoid_: Текущее поведение, baseline

**Integration Contract**:
Авторитетное описание requests, responses, правил authentication, errors и events при взаимодействии с внешним сервисом.
_Avoid_: Product specification, implementation plan

**Product Documentation Language**:
Русский текст с сохранением имён API, code identifiers, payload fields и других технических identifiers на английском языке.
_Avoid_: Перевод code или protocol identifiers

## Идентичность и контакты

**User Account**:
Идентичность, credentials, session и редактируемый Profile человека, который сейчас использует Messenger.
_Avoid_: Messenger User, Device Contact

**Authenticated Session**:
Состояние входа, поддерживаемое действующим access token либо refresh token, способным его обновить; logout или неудачный refresh завершают это состояние.
_Avoid_: User Account, Profile

**Messenger User**:
Зарегистрированный в Messenger человек, который может участвовать в Chats независимо от того, является ли он текущим пользователем или присутствует в адресной книге устройства.
_Avoid_: User Account, Device Contact

**Device Contact**:
Запись адресной книги устройства, которая может соответствовать или не соответствовать Messenger User.
_Avoid_: Messenger User, account

**Matched Contact**:
Подтверждённая связь между Device Contact и соответствующим Messenger User.
_Avoid_: Contact без уточнения

**Profile**:
Отображаемые и редактируемые персональные данные Messenger User, отделённые от идентичности и session в User Account.
_Avoid_: User Account, user

**Cached Profile**:
Последний локально сохранённый снимок Profile для немедленного отображения до замены успешным backend refresh.
_Avoid_: Authoritative Profile

## Messaging

**Chat**:
Постоянное direct- или group-пространство общения с участниками и Messages.
_Avoid_: Chat Session, Conversation как отдельная сущность

**Chat Session**:
Временный контекст взаимодействия с одним открытым Chat, включая видимую timeline и связанные с session действия.
_Avoid_: Chat, Conversation

**Conversation**:
Пользовательское обозначение процесса общения в Chat; не является отдельной доменной сущностью.
_Avoid_: Отдельная от Chat модель Conversation

**Direct Chat**:
Chat ровно с двумя Messenger Users, повторно используемый как канонический Chat для этой пары.
_Avoid_: Personal conversation, one-to-one session

**Group Chat**:
Именованный Chat с creator и одним или несколькими выбранными Messenger Users; другой Group Chat может иметь тот же состав.
_Avoid_: Состав участников как uniqueness key

**Message**:
Элемент timeline Chat с автором, timestamps и delivery state, который может содержать text, Attachment или reply reference.
_Avoid_: Attachment, event

**Attachment**:
Принадлежащие Message image, document, voice recording или video со сведениями о remote и local access.
_Avoid_: Message, media message как отдельная сущность

**Attachment Access State**:
Доступность Attachment через optimistic local source, remote `accessKey` или скачанную cache copy; не зависит от Message Delivery State.
_Avoid_: Message Delivery State, upload status как message status

**Message Delivery State**:
Видимый lifecycle исходящего Message: `sending` переходит в `sent`, `delivered` и `read`; ошибка создаёт `failed`, а retry возвращает `sending`. Server-reported state не сообщает, сколько участников Group Chat получили или прочитали Message.
_Avoid_: Upload state, Realtime Connection state

**Message Timeline Cache**:
Локальная timeline конкретного Chat с серверными и optimistic Messages, включая элементы `sending` и `failed`.
_Avoid_: Весь кеш как последняя успешно синхронизированная server timeline

## Соединение

**Network Connectivity**:
Наблюдаемая доступность сетевого интерфейса устройства; не гарантирует доступность backend-сервиса.
_Avoid_: Realtime Connection, backend availability

**Realtime Connection**:
WebSocket connection для получения live Message и receipt events; может быть отключён при доступной Network Connectivity.
_Avoid_: Network Connectivity

**Offline Capability**:
Read-only доступ к ранее кешированным данным при недоступной Network Connectivity; Messenger не поддерживает automatic offline send queue.
_Avoid_: Offline authoring, automatic queued sending

## Runtime Configuration

**Runtime Environment Profile**:
Единый immutable набор адресов auth, chat, file и WebSocket services, проверяемый до запуска зависимых product flows.
_Avoid_: Per-service environment, partially valid environment
