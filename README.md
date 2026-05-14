# Messenger Flutter Client

Minimal, dark Flutter client for the Rust messenger backend.

## Features

- Sign in (email or phone) / Register
- Real-time messaging via WebSocket
- Message status: pending → delivered → read (✓✓)
- Conversation list with unread badges
- Profile editing (first name, last name)
- Session persistence via shared_preferences
- Animated transitions, clean dark UI

## Setup

```bash
flutter pub get
flutter run
```

By default connects to:
- Auth HTTP: `http://127.0.0.1:3000`
- Chat WS:   `ws://127.0.0.1:3001/ws`

To change, edit `lib/services/auth_service.dart` and `lib/services/chat_service.dart`.

## Structure

```
lib/
  main.dart                  # App entry + root router
  theme.dart                 # Design tokens & ThemeData
  models/
    models.dart              # Message, UserInfo, Connection
  services/
    auth_service.dart        # HTTP auth calls
    chat_service.dart        # WebSocket chat
    app_state.dart           # Provider state management
  screens/
    auth_screen.dart         # Login / Register
    conversations_screen.dart
    chat_screen.dart
    profile_screen.dart
```

## Notes

- The backend uses `session_tocken` (legacy typo) — the client matches this exactly.
- WebSocket actions: `join`, `send_message`, `history`, `mark_read`, `list_connections`, `ping`
- Server events handled: `joined`, `message`, `history`, `read_receipt`, `connections`, `error`
# ytcm
