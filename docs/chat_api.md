# Chat Service API

**Base URL:** `http://localhost:8003`
**Swagger UI:** `http://localhost:8003/swagger/`

Значения выше относятся к локальному backend. Flutter-клиент получает REST
адрес Chat Service из `APP_CHAT_BASE_URL`, а WebSocket address — из
`APP_WS_BASE_URL`. Фактический порядок источников конфигурации описан в
[`README.md`](../README.md#runtime-configuration).

## Аутентификация

Все защищённые эндпоинты требуют JWT-токен в заголовке:

```
Authorization: Bearer <jwt-token>
```

JWT подписан алгоритмом HS256. Поле `sub` в payload содержит `user_id` (UUID).

---

## Формат ответов

Все ответы обёрнуты в единый конверт:

```json
{
  "status": "success",
  "data": { ... },
  "meta": { ... },
  "error": null
}
```

При ошибке:

```json
{
  "status": "error",
  "data": null,
  "meta": null,
  "error": {
    "code": "CHAT.NOT_FOUND",
    "message": "chat not found",
    "details": null
  }
}
```

### Коды ошибок

| Код | HTTP | Описание |
|-----|------|----------|
| `CHAT.VALIDATION_ERROR` | 422 | Ошибка валидации входных данных |
| `CHAT.NOT_FOUND` | 404 | Ресурс не найден |
| `CHAT.FORBIDDEN` | 403 | Нет прав доступа |
| `CHAT.DUPLICATE_ENTITY` | 409 | Дублирующая сущность |
| `CHAT.INVALID_TOKEN` | 401 | Невалидный или отсутствующий JWT |
| `CHAT.INTERNAL_ERROR` | 500 | Внутренняя ошибка сервера |

---

## Health

### GET /health

Проверка работоспособности сервиса.

**Аутентификация:** Не требуется

**Ответ 200:**

```json
{
  "status": "healthy",
  "service": "chat",
  "version": "1.0",
  "timestamp": "2026-03-29T12:00:00Z",
  "uptime": "2h30m",
  "database": {
    "connected": true,
    "error": ""
  },
  "system": {
    "go_version": "go1.24",
    "goroutines": 12,
    "num_cpu": 8
  }
}
```

### GET /api/v1/ping

Быстрая проверка доступности API.

**Аутентификация:** Не требуется

**Ответ 200:**

```json
{ "message": "pong" }
```

---

## Чаты

### POST /api/v1/chats

Создать чат.

**Аутентификация:** Требуется

**Тело запроса:**

```json
{
  "type": 1,
  "title": "Название группы",
  "member_ids": ["uuid-собеседника"]
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|----------|
| `type` | integer | да | `1` = личный, `2` = групповой |
| `title` | string | для type=2 | Название группового чата |
| `member_ids` | string[] | да | UUID участников. Для type=1 ровно 1 элемент; для type=2 от 1 до 99 |

**Ответ 201:**

```json
{
  "status": "success",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "type": 1,
    "title": null,
    "members": [
      {
        "user_id": "550e8400-e29b-41d4-a716-446655440000",
        "role": "admin",
        "added_at": "2026-03-29T12:00:00Z"
      },
      {
        "user_id": "...",
        "role": "member",
        "added_at": "2026-03-29T12:00:00Z"
      }
    ],
    "last_message": null,
    "unread_count": 0,
    "created_at": "2026-03-29T12:00:00Z",
    "updated_at": "2026-03-29T12:00:00Z"
  }
}
```

| Ошибка | Условие |
|--------|---------|
| 409 Conflict | Личный чат между этими пользователями уже существует |
| 422 Validation | Невалидные параметры (member_ids пуст, type неизвестен и т.д.) |

---

### GET /api/v1/chats

Список чатов текущего пользователя.

**Аутентификация:** Требуется

**Query-параметры:**

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|:---:|----------|
| `limit` | integer | 50 | Количество записей (max 200) |
| `offset` | integer | 0 | Смещение |

**Ответ 200:**

```json
{
  "status": "success",
  "data": {
    "chats": [
      {
        "id": "...",
        "type": 1,
        "title": null,
        "members": [...],
        "last_message": {
          "id": "...",
          "author_id": "...",
          "body": "Привет!",
          "created_at": "2026-03-29T12:00:00Z"
        },
        "unread_count": 3,
        "created_at": "...",
        "updated_at": "..."
      }
    ]
  },
  "meta": {
    "limit": 50,
    "offset": 0,
    "total": 12
  }
}
```

---

### GET /api/v1/chats/:chatId

Получить чат по ID. Только для участников.

**Аутентификация:** Требуется

**Ответ 200:** Объект `RoomResponse` (аналогично элементу в списке чатов).

| Ошибка | Условие |
|--------|---------|
| 403 Forbidden | Пользователь не является участником чата |
| 404 Not Found | Чат не найден |

---

### GET /api/v1/chats/personal

Получить ID личного чата с указанным пользователем.

**Аутентификация:** Требуется

**Query-параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|:---:|----------|
| `user_id` | string (UUID) | да | UUID собеседника |

**Ответ 200:**

```json
{
  "status": "success",
  "data": {
    "chat_id": "550e8400-e29b-41d4-a716-446655440001"
  }
}
```

| Ошибка | Условие |
|--------|---------|
| 404 Not Found | Личный чат не найден |
| 422 Validation | `user_id` не передан или совпадает с текущим пользователем |

**Поведение Flutter-клиента:** успешный ответ переиспользует возвращённый
`chat_id`. Только `404 Not Found` разрешает клиенту отправить `POST /chats` для
создания Direct Chat. Transport error, некорректный ответ или другой status
оставляют launch flow на recoverable экране и не запускают создание. Повторные
нажатия схлопываются только внутри одного активного client launch flow;
глобальная уникальность Direct Chat должна обеспечиваться backend.

---

## Сообщения

### POST /api/v1/chats/:chatId/messages

Отправить сообщение. Поддерживает дедупликацию по `client_message_id`.

**Аутентификация:** Требуется

**Тело запроса:**

```json
{
  "body": "Текст сообщения",
  "client_message_id": "unique-client-id",
  "attached_content": [
    {
      "access_key": "dGhpcyBpcyBhIHRlc3QgYmFzZTY0dXJsIGtleQ12abc",
      "type_content": "image",
      "file_name": "photo.jpg",
      "file_size": 1024,
      "mime_type": "image/jpeg"
    }
  ],
  "reply_to_message_id": null
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|----------|
| `body` | string\|null | нет* | Текст сообщения (max 4000 символов) |
| `client_message_id` | string | да | Уникальный ID от клиента (для дедупликации) |
| `attached_content` | object[] | нет* | Массив вложений (max 10) |
| `reply_to_message_id` | string\|null | нет | UUID сообщения, на которое отвечаем |

*Обязательно одно из двух: `body` или `attached_content`.

**Объект вложения (`attached_content[]`):**

| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|----------|
| `access_key` | string | да | Ключ доступа к файлу. Base64url без паддинга, ровно 43 символа. Regex: `^[A-Za-z0-9_-]{43}$` |
| `type_content` | string | да | Тип: `image`, `voice`, `video`, `document` |
| `file_name` | string | да | Имя файла |
| `file_size` | integer | да | Размер файла в байтах (> 0) |
| `mime_type` | string | да | MIME-тип файла |

**Ответ 201:**

```json
{
  "status": "success",
  "data": {
    "id": "msg-uuid",
    "chat_id": "chat-uuid",
    "author_id": "user-uuid",
    "body": "Текст сообщения",
    "client_message_id": "unique-client-id",
    "reply_to_message_id": null,
    "forwarded_from_message_id": null,
    "attached_content": [
      {
        "id": "att-uuid",
        "access_key": "dGhpcyBpcyBhIHRlc3QgYmFzZTY0dXJsIGtleQ12abc",
        "type_content": "image",
        "file_name": "photo.jpg",
        "file_size": 1024,
        "mime_type": "image/jpeg"
      }
    ],
    "created_at": "2026-03-29T12:00:00Z",
    "updated_at": null,
    "status": 1
  }
}
```

| Ошибка | Условие |
|--------|---------|
| 403 Forbidden | Пользователь не участник чата |
| 404 Not Found | Чат не найден |
| 422 Validation | Невалидные данные (пустое сообщение, невалидный `access_key`, и т.д.) |

---

### GET /api/v1/chats/:chatId/messages

Получить историю сообщений (cursor-пагинация, обратный хронологический порядок).

**Аутентификация:** Требуется

**Query-параметры:**

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|:---:|----------|
| `before` | string (ISO 8601) | now | Cursor: сообщения до этого момента |
| `limit` | integer | 100 | Количество сообщений (1-200) |

**Ответ 200:**

```json
{
  "status": "success",
  "data": {
    "messages": [
      {
        "id": "...",
        "chat_id": "...",
        "author_id": "...",
        "body": "Текст",
        "client_message_id": "...",
        "reply_to_message_id": null,
        "forwarded_from_message_id": null,
        "attached_content": [],
        "created_at": "2026-03-29T12:00:00Z",
        "updated_at": null,
        "status": 1
      }
    ]
  },
  "meta": {
    "limit": 100,
    "has_more": true
  }
}
```

**Пагинация:** Для загрузки следующей страницы используйте `created_at` последнего сообщения как `before`.

---

### PATCH /api/v1/chats/:chatId/messages/:messageId

Редактировать текст сообщения. Только автор.

**Аутентификация:** Требуется

**Тело запроса:**

```json
{
  "body": "Обновлённый текст"
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|----------|
| `body` | string | да | Новый текст (1-4000 символов) |

**Ответ 200:** Объект `MessageResponse` с обновлённым `body` и `updated_at`.

| Ошибка | Условие |
|--------|---------|
| 403 Forbidden | Не автор сообщения |
| 404 Not Found | Сообщение не найдено |

---

### DELETE /api/v1/chats/:chatId/messages/:messageId

Мягкое удаление сообщения.

**Аутентификация:** Требуется

**Тело запроса:**

```json
{
  "for_everyone": true
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|----------|
| `for_everyone` | boolean | да | `true` = удалить для всех (автор или admin), `false` = только для себя |

**Ответ 204:** No Content

| Ошибка | Условие |
|--------|---------|
| 403 Forbidden | Удаление для всех: пользователь не автор и не admin |
| 404 Not Found | Сообщение не найдено |

---

### POST /api/v1/chats/:chatId/messages/forward

Переслать сообщения в чат.

**Аутентификация:** Требуется

**Тело запроса:**

```json
{
  "message_ids": ["msg-uuid-1", "msg-uuid-2"]
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|----------|
| `message_ids` | string[] | да | UUID сообщений для пересылки (1-100) |

**Ответ 201:**

```json
{
  "status": "success",
  "data": {
    "messages": [
      {
        "id": "new-msg-uuid",
        "forwarded_from_message_id": "msg-uuid-1",
        "...": "..."
      }
    ]
  }
}
```

---

### POST /api/v1/chats/:chatId/read

Отметить сообщения прочитанными.

**Аутентификация:** Требуется

**Тело запроса:**

```json
{
  "up_to": "2026-03-29T12:00:00Z"
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|----------|
| `up_to` | string (ISO 8601) | да | Отметить все сообщения до этого момента как прочитанные |

**Ответ 204:** No Content

---

## Статусы сообщений

Поле `status` в объекте сообщения:

| Значение | Название | Описание |
|:---:|----------|----------|
| 1 | `sent` | Сообщение сохранено на сервере |
| 2 | `delivered` | Доставлено хотя бы одному получателю через WebSocket |
| 3 | `read` | Прочитано получателем (через `POST /read` или при загрузке истории) |

Статус продвигается только вперёд: `sent → delivered → read`.

---

## WebSocket

### GET /ws?token=\<jwt\>

Устанавливает WebSocket-соединение для real-time событий.

**Аутентификация:** JWT передаётся через query-параметр `token`.

**Подключение:**

```javascript
const ws = new WebSocket('ws://localhost:8003/ws?token=<jwt>');
```

**Формат сообщений (JSON):**

```json
{
  "type": "event_type",
  "payload": { ... }
}
```

### Серверные события (сервер -> клиент)

#### `new_message`

Новое сообщение в чате, участником которого вы являетесь.

```json
{
  "type": "new_message",
  "payload": {
    "chat_id": "chat-uuid",
    "message": {
      "ID": "msg-uuid",
      "ChatID": "chat-uuid",
      "AuthorID": "user-uuid",
      "Body": "Текст",
      "ClientMessageID": "...",
      "ReplyToMessageID": null,
      "ForwardedFromMessageID": null,
      "DeletedForEveryone": false,
      "CreatedAt": "2026-03-29T12:00:00Z",
      "UpdatedAt": null,
      "Attachments": [
        {
          "ID": "att-uuid",
          "MessageID": "msg-uuid",
          "AccessKey": "dGhpcyBpcyBhIHRlc3QgYmFzZTY0dXJsIGtleQ12abc",
          "TypeContent": "image",
          "FileName": "photo.jpg",
          "FileSize": 1024,
          "MimeType": "image/jpeg"
        }
      ],
      "Status": 1
    }
  }
}
```

> **Важно:** В WS-событиях `new_message` объект `message` сериализуется напрямую из Go-структуры (PascalCase поля), в отличие от REST API (snake_case).

#### `edit_message`

Сообщение отредактировано.

```json
{
  "type": "edit_message",
  "payload": {
    "chat_id": "chat-uuid",
    "message_id": "msg-uuid",
    "new_body": "Обновлённый текст"
  }
}
```

#### `delete_message`

Сообщение удалено для всех.

```json
{
  "type": "delete_message",
  "payload": {
    "chat_id": "chat-uuid",
    "message_id": "msg-uuid"
  }
}
```

#### `message_read`

Пользователь прочитал сообщения в чате.

```json
{
  "type": "message_read",
  "payload": {
    "chat_id": "chat-uuid",
    "user_id": "reader-uuid",
    "read_up_to": "2026-03-29T12:00:00Z"
  }
}
```

#### `message_status_changed`

Статус сообщения изменился (delivered/read). Доставляется только автору сообщения.

```json
{
  "type": "message_status_changed",
  "payload": {
    "chat_id": "chat-uuid",
    "message_id": "msg-uuid",
    "status": 2
  }
}
```

#### `member_added`

Новый участник добавлен в чат.

```json
{
  "type": "member_added",
  "payload": {
    "chat_id": "chat-uuid",
    "user_id": "new-member-uuid"
  }
}
```

#### `member_removed`

Участник удалён из чата.

```json
{
  "type": "member_removed",
  "payload": {
    "chat_id": "chat-uuid",
    "user_id": "removed-member-uuid"
  }
}
```

#### `chat_updated`

Параметры чата обновлены (название и т.д.).

```json
{
  "type": "chat_updated",
  "payload": {
    "chat_id": "chat-uuid",
    "room": {
      "ID": "chat-uuid",
      "Type": 2,
      "Title": "Новое название",
      "...": "..."
    }
  }
}
```

### Клиентские события (клиент -> сервер)

#### `user_typing`

Уведомление о наборе текста. Throttle: не чаще 1 раза в 3 секунды на пару (user, chat).

```json
{
  "type": "user_typing",
  "payload": {
    "chat_id": "chat-uuid"
  }
}
```

Сервер рассылает `user_typing` всем участникам чата (кроме отправителя):

```json
{
  "type": "user_typing",
  "payload": {
    "chat_id": "chat-uuid",
    "user_id": "typing-user-uuid"
  }
}
```

### Коды закрытия WebSocket

| Код | Описание |
|:---:|----------|
| 4001 | Невалидный или отсутствующий JWT |
| 4400 | Невалидный JSON |

### Доставка и подписки

- Клиент автоматически подписан на все чаты, участником которых он является.
- При добавлении/удалении из чата подписки обновляются динамически.
- Событие `new_message` автоматически триггерит обновление статуса сообщения (`sent → delivered`) для получателей.
