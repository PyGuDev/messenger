# Contract: Chat Session Behavior

## Purpose

Определяет ожидаемое client-side поведение восстановления message timeline,
изоляции состояния каждого Chat и запуска Chat из контакта в рамках
стабилизации.

## 1. Timeline Restore Contract

- `Message Timeline Cache` читается и записывается по `chatId`; чтение cache
  одного `Chat Session` никогда не должно вернуть записи другого Chat.
- При входе в Chat Flutter-клиент читает непустую local timeline до запроса
  первой remote-страницы history. Cached timeline остаётся видимой во время
  refresh.
- До замены cached первой страницы Chat клиент исключает полученные записи, у
  которых `chat_id` отличается от route `chatId`. Затем он сохраняет по одной
  записи на identity Message: `client_message_id`, если он есть, иначе server
  message ID; при совпадении identity выбирается запись с более поздним
  `updated_at`. Получившаяся страница в порядке от новых к старым заменяет
  только cache rows этого Chat.
- Это не является reconciliation cached и fetched timeline: текущий refresh
  заменяет cache только remote-страницей и поэтому может удалить local
  Messages со status `sending` или `failed`. Это известное отклонение текущего
  продукта, а не гарантия сохранения optimistic Messages.
- У текущего клиента нет persisted successful-sync marker. Поэтому пустой cache
  означает либо первое открытие, либо ранее синхронизированный Chat без cached
  записей. Если cache пуст и history request не завершился — включая отсутствие
  connectivity, transport, backend или parsing error — UI показывает
  chat-specific state `MessagesOfflineUnavailable`. Непустая cached timeline
  остаётся видимой при ошибке refresh.
- Session-specific draft, reply, emoji, voice/video recording и camera state не
  должны сохраняться в другом Chat после navigation.

## 2. Session Ownership Contract

- `MessagesBloc` принадлежит route/session scope, а не app-global scope.
- Вход на `/chat/:id` создаёт ровно один `MessagesBloc`, camera service и
  voice-recording service для этого `Chat Session`; их provider subtree имеет
  ключ `chatId`.
- `MessagesBloc` принимает `ChatSessionEvent`, только если event `chatId`
  совпадает с Chat Session. Его WebSocket subscription отфильтрована по тому же
  Chat и отменяется при закрытии bloc.
- Выход из route освобождает route-local camera и voice-recording services.
  При dispose message screen очищает draft, reply target, recording flags и
  связанные controllers. Application-wide WebSocket connection не закрывается
  только из-за завершения Chat Session.

## 3. Contact-to-Chat Launch Contract

- UI entry points dispatch an intent to open a direct conversation; they do not call chat APIs directly.
- Canonical direct-chat behavior is:
  1. Check for an existing one-to-one chat for the target contact.
  2. Reuse it if present.
  3. Create a new direct chat only if no existing match is found.
- If launch fails, the user remains on a recoverable screen and receives a clear failure message.
- Repeated launch attempts while one request is active must not create duplicate chats.
- A `404` from direct-chat lookup is the only lookup outcome that permits the
  client to request creation. Transport errors, malformed responses, and other
  status codes remain recoverable failures and must not trigger creation.
- This client-side in-flight guard is scoped to one launch flow; canonical
  uniqueness across clients remains a backend responsibility.

## 4. Documentation Alignment

- If implementation requires contract changes to existing chat lookup/create semantics, update `docs/chat_api.md` in the same change.
- If media/file behavior or environment setup expectations change, update `docs/FRONTEND_API_GUIDE.md` in the same change.
