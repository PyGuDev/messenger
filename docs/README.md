# Документация Messenger

Этот файл — единая точка входа в документацию проекта. Документы разделены
по назначению, чтобы текущее поведение продукта не смешивалось с планами и
серверными контрактами.

## Источники истины

1. [Messenger Constitution](../.specify/memory/constitution.md) — обязательные
   инженерные принципы и правила поставки.
2. [Product Baseline](../specs/002-document-current-product/spec.md) —
   проверяемое пользовательское поведение текущей реализации. Привязан к
   Verification Commit, но пока имеет статус `Draft`, поскольку не завершены
   manual journeys и остальные Success Criteria.
3. Integration Contracts — ожидаемые протоколы взаимодействия клиента с
   backend-сервисами.
4. Feature Specifications — требования и планы отдельных изменений; они не
   описывают текущее поведение, пока изменение не реализовано и не проверено.

## Integration Contracts

- [Chat Service API](./chat_api.md) — REST и WebSocket для Chats и Messages.
- [File Service API](./FRONTEND_API_GUIDE.md) — upload, download, metadata и
  правила использования `accessKey`.
- [Auth and Profile Client Contract](./auth_api.md) — наблюдаемые ожидания
  Flutter-клиента. Требует сверки с backend/OpenAPI и пока не является
  официальным серверным контрактом.

## Feature Specifications

- [001 — Flutter Stabilization](../specs/001-flutter-stabilization/spec.md) —
  частично реализованный пакет стабилизации кеша, Chat Session,
  contact-to-chat flow и runtime-конфигурации.
- [001 — Implementation Plan](../specs/001-flutter-stabilization/plan.md) —
  технический план той же стабилизации.
- [001 — Tasks](../specs/001-flutter-stabilization/tasks.md) — фактический
  прогресс и оставшиеся проверки.

## Термины

- [CONTEXT.md](../CONTEXT.md) — канонический словарь предметной области и
  документации.

## Статусы

- `Draft` — документ ещё не прошёл полную проверку; наличие Verification Commit
  само по себе не означает выполнение всех Success Criteria.
- `Verified` — документ проверен по UI, коду и тестовому либо воспроизводимому
  manual-сценарию и привязан к конкретному Git commit.
- `Superseded` — документ заменён более новым; ссылка на замену обязательна.
