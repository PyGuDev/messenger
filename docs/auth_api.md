# Auth and Profile Client Contract

**Status**: Client-observed / Requires backend verification

**Observed**: 2026-08-16

**Base URL**: значение `APP_AUTH_BASE_URL` из Runtime Environment Profile

Документ фиксирует запросы и ответы, которые ожидает текущий Flutter-клиент.
Он получен из клиентского кода, а не из OpenAPI или backend-репозитория,
поэтому не является официальным серверным контрактом.

## Общие правила клиента

- Основной auth-клиент добавляет `Authorization: Bearer <access_token>`, если
  access token сохранён. Это относится и к `signin`/`signup`.
- После ответа `401` клиент вызывает `POST /auth/refresh`, сохраняет новую пару
  токенов и повторяет исходный запрос.
- Одновременно выполняется не более одного refresh.
- Если refresh невозможен, локальные токены удаляются и Authenticated Session
  завершается.
- Серверного logout-запроса нет: logout удаляет Cached Profile текущего User
  Account до очистки credentials, очищает локальную session и отключает
  Realtime Connection. Ошибка удаления Cached Profile диагностируется, но не
  сохраняет authenticated UI state.

## Authentication

### `POST /auth/signin`

Запрос:

```json
{
  "email": "user@example.com",
  "password": "password"
}
```

Клиент принимает плоский объект или объект в поле `data`. Ожидаемые поля:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "user_id": "user-uuid"
}
```

Вместо `user_id` также распознаётся `id`. После успеха токены и идентификатор
сохраняются, затем клиент открывает Realtime Connection.

### `POST /auth/signup`

Запрос:

```json
{
  "email": "user@example.com",
  "firstName": "Ivan",
  "lastName": "Ivanov",
  "password": "password",
  "confirmPassword": "password",
  "phone": "+79990000000"
}
```

Форма успешного ответа совпадает с `signin`; после успеха сразу создаётся
локальная Authenticated Session.

### `POST /auth/refresh`

Запрос:

```json
{
  "refresh_token": "..."
}
```

Клиент ожидает только плоский ответ:

```json
{
  "access_token": "...",
  "refresh_token": "..."
}
```

Envelope `{ "data": { ... } }` для refresh текущим клиентом не поддерживается.

## Profile

### `GET /profile`

Возвращает плоский `UserProfile`. Клиент может сначала показать Cached Profile,
принадлежащий только текущему сохранённому `user_id`, после чего успешный ответ
заменяет локальный снимок этого User Account. Глобальный legacy cache без
доказуемого владельца удаляется и не мигрируется.

### `PATCH /profile`

Edit Profile screen при каждом сохранении передаёт текущие значения всех четырёх
полей. Поэтому обычный UI flow отправляет полный payload, даже если пользователь
изменил только одно поле:

```json
{
  "firstName": "Ivan",
  "lastName": "Ivanov",
  "phone": "+79990000000",
  "email": "user@example.com"
}
```

Ожидается плоский `UserProfile`; только успешный ответ сохраняется как Cached
Profile текущего User Account. Во время запроса UI показывает отдельный update
progress. Успех и ошибка представлены разными состояниями: edit screen
закрывается только после success, а при failure остаётся открытым и сохраняет
введённые значения для retry.

## Users

### `GET /users/{userId}`

Возвращает плоский `UserProfile`. Клиент кеширует результат в памяти. Ошибка
преобразуется в пустой профиль, а не передаётся вызывающему коду.

### `GET /users/search`

Поддерживаемые query-параметры: непустой `phone` и/или `email`. Клиент ожидает
корневой JSON-массив профилей, полученный как plain text. Пустой запрос не
отправляется; ошибка или некорректный JSON преобразуются в пустой список.

## UserProfile

Клиент распознаёт несколько вариантов имён полей:

| Значение | Поддерживаемые поля |
|---|---|
| ID | `id`, `ID`, `userId`, `userID` |
| Имя | `firstName` |
| Фамилия | `lastName` |
| Телефон | `phone` |
| Email | `email` |

Отсутствующие строки заменяются на `""`; неожиданный тип значения может
привести к ошибке parsing.

## Неподтверждённые части backend-контракта

До сверки с OpenAPI или backend-командой нельзя утверждать:

- обязательность, формат и допустимую длину полей;
- точные success status codes и полный error envelope;
- срок жизни токенов и состав JWT claims;
- поддержку envelope для refresh;
- серверный формат телефона для signup и profile update;
- отзыв серверной сессии при локальном logout;
- гарантированный строковый тип идентификаторов;

## Известные клиентские ограничения

- При старте наличие любого access token трактуется как Authenticated Session;
  срок действия до первого `401` не проверяется.
- UserService и AuthInterceptor пока не имеют прямого автоматического
  покрытия request/error paths.
