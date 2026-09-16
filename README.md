# YeChat

Flutter client for the Rust messenger backend in
`/home/leo/dev/rust/messenger-main`.

## Features

- Sign in (email or phone) / Register
- Real-time messaging via WebSocket
- Message status: pending → delivered → read (✓✓)
- Conversation list with unread badges
- Profile editing (username, name, birth date, bio, and avatar)
- Session persistence via shared_preferences
- Direct and group file attachments
- Android background notification polling without a permanent online session
- Configurable auth, chat, and file-service endpoints
- Offline send queue for text and uploaded attachments
- Copy/delete message actions and richer group creation

## Setup

```bash
flutter pub get
flutter run
```

Desktop builds use the hosted Yechat endpoints by default. Mobile builds require
the three service URLs to be entered in **Server settings**. For a local backend:

- Auth HTTP: `http://127.0.0.1:25461`
- Chat WS: `ws://127.0.0.1:25462/ws`
- File WS: `ws://127.0.0.1:25463/ws`

Use the machine's LAN address instead of `127.0.0.1` on a physical phone.
When a WebSocket URL has no path, Server settings automatically adds `/ws`.
Connection tests distinguish reverse-proxy outages (`502`/`503`) from invalid
URLs and unreachable devices.

## Verification

```bash
flutter analyze
flutter test
flutter build linux --debug
```

## Structure

```
lib/
  main.dart                  # App entry + root router
  theme.dart                 # Design tokens & ThemeData
  models/
    models.dart              # Message, UserInfo, Connection
  services/
    auth_service.dart        # HTTP auth calls
    chat_service.dart        # WebSocket chat and reconnect state
    file_service.dart        # Chunked WebSocket upload/download
    app_state.dart           # Provider state management
  screens/
    auth_screen.dart         # Login / Register
    conversations_screen.dart
    chat_screen.dart
    profile_screen.dart
```

## Notes

- The backend uses `session_tocken` (legacy typo) — the client matches this exactly.
- Chat recipients must be UUIDs. This backend's `/getuserinfo` response does not
  expose another user's UUID, so a new user can be found by username only while
  they are online (or after their UUID has already been cached).
- The backend has no dialog-list endpoint. The client restores locally known
  conversations and requests their server history after joining.
- Direct-message send/history/read/delete events and the group create/list/send/
  history/read/member/delete event families are handled.
