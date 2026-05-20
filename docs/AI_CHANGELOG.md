# AI handoff / changelog

Этот файл ведётся **явно**: сюда записываются значимые изменения, решения и контекст, чтобы другая нейросеть или новая сессия могла быстро подхватить состояние проекта.

## Как пользоваться

1. **Перед началом работы** прочитай последние разделы «Текущее состояние» и «Недавние записи».
2. **После смыслового изменения** (фича, фикс, рефакторинг, смена контракта API) добавь запись в «Недавние записи» по шаблону ниже.
3. **Не дублируй** весь diff — укажи *что* и *зачем*, плюс пути к ключевым файлам.

## Шаблон новой записи

Скопируй блок и заполни:

```markdown
### YYYY-MM-DD — краткий заголовок

- **Задача / запрос:** …
- **Сделано:** …
- **Файлы / области:** `path/to/file`, …
- **Контракты / API:** если менялись эндпоинты, WS-сообщения, схемы БД — перечисли.
- **Осталось / риски:** …
- **Как проверить:** команды или шаги в UI.
```

---

## Текущее состояние (кратко)

- **Клиент:** Flutter (`lib/`), WebSocket к chat-service и file-service, HTTP к auth-service. Настройки: [`lib/services/server_settings.dart`](../lib/services/server_settings.dart) — auth URL, chat WS URL, **file WS URL**. Локализация: [`assets/l10n/`](../assets/l10n/) (`strings_<код>.json`), [`lib/services/locale_controller.dart`](../lib/services/locale_controller.dart).
- **Сервер:** папка [`messenger/`](../messenger/) — workspace на Rust (auth, chat-service с группами и 1:1, file-service). Контракты: [`messenger/API_REFERENCE.md`](../messenger/API_REFERENCE.md) (в т.ч. `GET /userpresence`), файлы: [`messenger/file-service/API_DOCUMENTATION.md`](../messenger/file-service/API_DOCUMENTATION.md).
- **Дорожная карта / детали фич:** [`docs/MESSENGER_FEATURES_SPEC.md`](MESSENGER_FEATURES_SPEC.md) — основная часть реализована в клиенте и auth; доработки по желанию (полный перевод всех экранов, тонкая настройка уведомлений).

*Обновляй этот блок при существенных сдвигах архитектуры.*

---

## Недавние записи

### 2026-05-20 — Авто-список языков и локализация служебных строк

- **Задача / запрос:** показать языки в настройках по доступным `strings_*.json`, локализовать оставшиеся служебные сообщения и подсказки.
- **Сделано:** `LocaleController` теперь читает `locale.name` из файлов перевода и отдаёт человекочитаемые названия в настройках; локализованы ошибки входа/регистрации, подсказка поиска чата, статус ожидания соединения и часть уведомлений/превью вложений.
- **Файлы / области:** `lib/services/locale_controller.dart`, `lib/services/app_state.dart`, `lib/screens/server_settings_screen.dart`, `lib/screens/conversations_screen.dart`, `assets/l10n/strings_en.json`, `assets/l10n/strings_ru.json`.
- **Контракты / API:** не менялись.
- **Осталось / риски:** часть технических ошибок от сервера всё ещё приходит как есть; если нужно, можно отдельно пройтись по ним и перевести в явные локальные ключи.
- **Как проверить:** открыть настройки и список языков; проверить, что ошибки формы и подсказка нового чата отображаются на текущем языке.

### 2026-05-20 — Реализация MESSENGER_FEATURES_SPEC

- **Задача / запрос:** last seen, уведомления, i18n (`strings_en`/`strings_ru`), файлы, группы по [MESSENGER_FEATURES_SPEC.md](MESSENGER_FEATURES_SPEC.md).
- **Сделано:** Auth `GET /userpresence`; Flutter: `LocaleController` + assets, `MessengerNotifications`, `FileTransferService`, расширенный `ChatService` (группы), `AppState` (группы, presence, lifecycle offline), вкладки Сообщения/Группы, `GroupChatScreen`, вложения в DM/группах, настройки (file WS + язык), документация API.
- **Файлы / области:** `messenger/auth-service/src/{structs,core,api}.rs`, `lib/services/*`, `lib/screens/{conversations,chat,group_chat,server_settings}.dart`, `lib/main.dart`, `assets/l10n/*.json`, `pubspec.yaml`, `android/.../AndroidManifest.xml`, `messenger/API_REFERENCE.md`.
- **Контракты / API:** новый `GET /userpresence?session_tocken=&user_id=`.
- **Как проверить:** `cargo check -p reg` в `messenger/`; `flutter pub get` и `flutter run`; три сервиса (auth, chat, file) для полного сценария вложений.

### 2026-05-20 — Спецификация фич мессенджера (блок Plan mode)

- **Задача / запрос:** last seen, уведомления на входящие, i18n (`strings_*`), файлы, группы; сервер в `messenger/`.
- **Сделано:** добавлен подробный чертёж реализации в [`MESSENGER_FEATURES_SPEC.md`](MESSENGER_FEATURES_SPEC.md) (эндпоинт `GET /userpresence`, клиент, уведомления, l10n, file WS, группы по API_REFERENCE). Автопатч коду не применён — **Plan mode** и отклонённый переход в Agent.
- **Файлы / области:** `docs/MESSENGER_FEATURES_SPEC.md`
- **Контракты / API:** предложен новый `GET /userpresence` (ещё не в репозитории до ручного/Agent патча).
- **Осталось / риски:** включить **Agent mode** и реализовать по спецификации, либо перенести патчи вручную.
- **Как проверить:** открыть `docs/MESSENGER_FEATURES_SPEC.md`.

### 2026-05-20 — Создан файл handoff для нейросетей

- **Задача / запрос:** отдельный файл с явным отслеживанием изменений для передачи контекста между моделями/сессиями.
- **Сделано:** добавлен `docs/AI_CHANGELOG.md` с правилами ведения и шаблоном.
- **Файлы / области:** `docs/AI_CHANGELOG.md`
- **Контракты / API:** не менялись.
- **Осталось / риски:** по желанию — связать этот файл с правилом в `.cursor/rules` или `AGENTS.md`, чтобы агенты всегда читали его первым.
- **Как проверить:** открыть этот файл в репозитории.

---

## Очередь / идеи (не обязательно к исполнению)

Переноси отсюда в «Недавние записи», когда начнёшь и закончишь работу.

- (пусто)
