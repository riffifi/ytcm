# Спецификация: last seen, уведомления, i18n, файлы, группы

Среда **Cursor Plan mode** заблокировала автоматическое применение патчей к Rust/Dart. Чтобы агент мог править код, включите **Agent mode** и попросите: «реализуй по `docs/MESSENGER_FEATURES_SPEC.md`».

---

## 1. Последний онлайн (`был в сети в 00:00`)

### Бэкенд (auth-service)

В БД уже есть `user_profile.last_online` и `is_online`; `user_offline` обновляет `last_online`, `user_online` ставит `is_online = TRUE`.

**Добавить:**

- В [`messenger/auth-service/src/structs.rs`](../messenger/auth-service/src/structs.rs): `GetUserPresence { session_tocken, user_id }`, `UserPresence { is_online, last_online: Option<String> }` (оба сериализуемые как нужно).
- В [`messenger/auth-service/src/core.rs`](../messenger/auth-service/src/core.rs): `get_user_presence(pool, session_token, target_user_id)` — проверить сессию, `SELECT is_online, last_online::TEXT FROM user_profile WHERE uuid = $1`.
- В [`messenger/auth-service/src/api.rs`](../messenger/auth-service/src/api.rs): `GET /userpresence?session_tocken=...&user_id=<uuid>` → JSON `UserPresence` или 404.

**Клиент:** в [`lib/services/auth_service.dart`](../lib/services/auth_service.dart) метод `Future<UserPresence?> getUserPresence(token, userId)`. В [`AppState`](../lib/services/app_state.dart) кэш/периодическое обновление при открытии чата и в списке диалогов; в UI форматировать через `intl` / строки i18n.

**Онлайн «прямо сейчас»:** если `peerId` есть в `list_connections` от chat-service — считать онлайн; иначе смотреть `is_online` из `/userpresence` (оба источника можно слить: онлайн = в списке подключений ИЛИ `is_online`).

---

## 2. Уведомление после каждого принятого сообщения

- Зависимости: `flutter_local_notifications`, при необходимости `permission_handler` (Android 13+).
- Инициализация в `main.dart` до `runApp` (канал Android, минимальные настройки iOS).
- В `AppState._onMessage` (и в обработчике **групповых** сообщений): если `senderId != me`, и чат с этим peer **не** активен или приложение в фоне (`WidgetsBindingObserver`, `AppLifecycleState`), вызвать `show(...)` с заголовком = имя отправителя, текст = превью сообщения.
- Идентификатор уведомления: хэш от `peerId` (DM) или `groupId` (группа), чтобы не спамить дубликатами при обновлении одной «сессии».

---

## 3. Локализация: один каталог строк, файлы `*_en` / `*_ru`, авто-список языков

**Рекомендуемая схема:**

- Каталог [`assets/l10n/`](../assets/l10n/): `strings_en.json`, `strings_ru.json` (паттерн `strings_<locale>.json`).
- В [`pubspec.yaml`](../pubspec.yaml): `flutter: assets: - assets/l10n/`
- Класс `AppLocalizations` / `LocaleController` (`ChangeNotifier`): загрузка JSON по выбранному коду, ключи плоские или вложенные (`"chat.title"`).
- **Авто-обнаружение языков:** при старте прочитать `rootBundle.loadString('AssetManifest.json')`, взять ключи, совпадающие с `RegExp(r'assets/l10n/strings_([a-zA-Z-]+)\.json$')`, вывести коды в настройках (`DropdownButton` / `ListTile`).
- Сохранение выбора: `SharedPreferences` (`locale_code`).
- Обернуть `MaterialApp` в `ListenableBuilder` / `Consumer` и передать `locale: Locale(code)`.
- Постепенно заменить литералы в экранах на `context.l10n.str('key')` (или extension на `BuildContext`).

---

## 4. Файлы и изображения

- В [`lib/services/server_settings.dart`](../lib/services/server_settings.dart): поле **file WebSocket URL** (по умолчанию `ws://127.0.0.1:25463/ws` или как в [`messenger/file-service/config.toml`](../messenger/file-service/config.toml)), сохранение в prefs.
- Новый сервис `FileTransferService`: WebSocket по протоколу из [`messenger/file-service/API_DOCUMENTATION.md`](../messenger/file-service/API_DOCUMENTATION.md) (`message_type` + `data`, затем binary chunks).
- Зависимости: `file_picker`, опционально `image_picker`.
- После успешного `file_id`: `chat.sendMessage(receiverId: ..., text: optionalCaption, fileId: id)` — уже поддерживается в [`lib/services/chat_service.dart`](../lib/services/chat_service.dart).
- UI чата: кнопка скрепки → выбор файла → прогресс → отправка. Для отображения: загрузка через WS `download` (отдельный клиент или тот же канал) и показ `Image.memory` / иконка типа файла.

**Доступ получателя:** при необходимости вызывать `grant_access` на file-service для `receiver_id` (см. документацию и интеграцию chat-service с file-service).

---

## 5. Группы (сервер уже готов)

Контракт: [`messenger/API_REFERENCE.md`](../messenger/API_REFERENCE.md) (разделы group / `group_*` события).

**Расширить [`lib/services/chat_service.dart`](../lib/services/chat_service.dart):**

- Парсинг серверных типов: `group_message`, `group_history`, `groups`, `group_created`, … (как в `ServerEvent` в [`messenger/chat-service/src/api.rs`](../messenger/chat-service/src/api.rs)).
- Методы отправки: `createGroup`, `listGroups`, `sendGroupMessage`, `groupHistory`, `markGroupRead`, `addGroupMember`, … по `action` из API_REFERENCE.

**Модели:** в [`lib/models/models.dart`](../lib/models/models.dart) — `StoredGroup`, `GroupMessage` (поля как в `StoredGroupMessage` в Rust).

**AppState:** отдельные `Map<String, List<GroupMessage>>`, список групп, `activeGroupId`, подписки на стримы из `ChatService`, синхронизация с `list_groups` после `join`.

**UI:** экран списка групп (FAB «создать»), экран группового чата (переиспользовать пузыри с `group_id`), экран информации о группе (участники, роли) через `group_info` / события членства.

---

## 6. Прочее

- **Lifecycle:** при уходе в фон опционально вызывать `auth.setOffline` для корректного `last_online` (учитывать, что WS может рваться — согласовать с продуктом).
- Обновить [`docs/AI_CHANGELOG.md`](AI_CHANGELOG.md) после внедрения.
- Прогнать `flutter analyze` и `cargo build` в `messenger/`.

---

## Порядок внедрения (рекомендуемый)

1. Auth `userpresence` + Flutter вызов + подпись в UI last seen.  
2. `flutter_local_notifications` + хук в `_onMessage`.  
3. JSON l10n + настройки языка.  
4. File URL в настройках + upload + вложения в DM (затем группы).  
5. Полный клиент групп по API_REFERENCE.
