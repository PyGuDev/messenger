# Checklist качества: Product Baseline Messenger

**Назначение**: проверить пригодность baseline как воспроизводимого описания
текущего продукта.

**Создан**: 2026-08-15

**Документ**: [spec.md](../spec.md)

## Содержание

- [x] Текущее поведение отделено от будущих Feature Specifications
- [x] Пользовательские пути и границы продукта перечислены
- [x] Неподтверждённые и частично реализованные гарантии вынесены в Known Deviations
- [x] Доменные термины ссылаются на `CONTEXT.md`
- [x] Integration Contracts разделены на server contract и client-observed contract
- [x] Product documentation написана по-русски с сохранением технических identifiers

## Проверка реализации

- [x] Выполнен code-level аудит UI paths и state flows
- [x] Выполнен `flutter test`: 38 tests passed
- [x] Выполнен `flutter analyze`: no issues found
- [ ] Пройдены manual journeys из раздела User Stories
- [ ] Добавлено недостающее automated coverage для оставшихся auth, group,
      media, realtime, pagination и switch Chat сценариев; Profile cache/update
      и Auth logout покрыты focused BLoC/widget tests; lifecycle route-scoped
      MessagesBloc и Matched Contacts state покрыты
- [ ] Known Deviations устранены либо приняты как явные продуктовые ограничения

## Готовность статуса

- [x] `Draft` содержит дату и ветку обследованного рабочего дерева
- [x] Документ привязан к конкретному Git commit
- [ ] Все Success Criteria для перехода в `Verified` выполнены
- [ ] Статус изменён с `Draft` на `Verified`

## Notes

- Baseline привязан к Verification Commit
  `79a2718ee43c0b9d0beb7e5c3bec63ab2d29e4e2`, но остаётся `Draft`, пока manual
  journeys и остальные Success Criteria не выполнены.
- Dormant handlers без UI entry point не считаются продуктовой возможностью.
