# YeChat — UI/UX Redesign Specification

**Audience:** an implementing engineer or coding agent (e.g. Claude Code) working directly in this repo.
**Scope:** Flutter presentation layer only — widgets, screens, theme, motion, icons, layout.
**Explicitly out of scope:** `services/` business logic, WebSocket/HTTP protocol, `models/`, backend behavior, `AppState` public API shape. Where a screen needs new *data* (e.g. "last activity" on a group tile) prefer deriving it from data `AppState` already exposes; if something is truly unavailable, it's called out under "Needs data" and should degrade gracefully rather than block the redesign.

This document is meant to be read top to bottom and executed roughly in the order it's written. It is deliberately exhaustive: it names exact files, exact widgets, and exact inconsistencies found in the current codebase (`ytcm/lib`), then specifies the target state precisely enough to implement without further product decisions. Where a decision is genuinely open, it's flagged in §12.

---

## 0. What YeChat is today

A Flutter messenger client (`lib/`) talking to a Rust backend, with:

- Auth (email/phone login + register)
- 1:1 chat with WebSocket real-time delivery, offline queue, read receipts (✓✓)
- Groups/channels (create, edit, members, roles, leave)
- File & image attachments, GIF search (Tenor), emoji picker
- Profile editing + avatar upload
- Light/dark theme with 6 selectable accent palettes, a real typographic system (Geist variable font), and a working design-token file (`lib/theme.dart`)
- Responsive shell: bottom nav on mobile, `NavigationRail` + master-detail on desktop/wide

**The foundation is good.** `theme.dart` is a genuinely well-built token system: semantic colors (`bg/surface/surfaceHigh/border/...`), a variable-weight type scale (`AppFontWeight.body/medium/semibold/heading/display`), themed `ElevatedButton`/`InputDecoration`/`Card`/`Dialog`/`BottomSheet`/`NavigationBar`. The auth screen and the message bubble/composer are close to production quality.

**The problem is consistency, not taste.** Roughly a third of the screens use the token system faithfully; the rest reach for raw `TextStyle(...)`, default Material `Icon(Icons.*)`, ad-hoc radii, and one-off copies of patterns that already exist elsewhere. The result reads like several people worked on it without a shared checklist — which is exactly what makes a UI feel half-baked even when no single screen is "bad." This spec's job is to close that gap everywhere, in one pass, with one checklist.

---

## 1. Diagnosis — specific findings

Every item below is a concrete, file-and-symbol-level inconsistency found by reading the current source. Fixing these *is* the redesign; §4–§6 turn them into a target spec.

### 1.1 Typography: token system vs. raw `TextStyle`

`AppTheme.text/heading/appBarTitle/display/sectionLabel` exist and are used correctly in `auth_screen.dart`, `chat_app_bar_title.dart`, `home_shell.dart`. But raw `TextStyle(color: c.primary, fontSize: 15, fontWeight: FontWeight.w500)` (hand-picked size/weight, ignoring the Geist `wght` axis and the scale) appears throughout:

- `conversations_screen.dart` — `_ConversationTile` (name, preview, timestamp), `_NewChatSheet` (title, chip labels, "Connected now" captions)
- `chat_message_tile.dart` — `_Bubble` timestamp, `_DateDivider` label (bubble text itself correctly uses `AppTheme.text` via `MessageBody`, but its own chrome doesn't)
- `group_chat_screen.dart` — the entire `_GroupBubble` (sender name, timestamp) and app-bar subtitle partially
- `settings_screen.dart` — `_NavTile`, `_PaletteChip`, "Color story" caption, notification switch title/subtitle
- `profile_screen.dart`, `user_profile_screen.dart` — display name, `@username`, bio/info card values, `_ActionTile`
- `groups_screen.dart` — list tile title/subtitle
- `server_settings_screen.dart` — help captions use `Theme.of(context).textTheme.bodyMedium` (a *third* pattern, neither raw `TextStyle` nor `AppTheme.text`)
- `file_attachment.dart`, `conversation_context_menu.dart`, `group_details_screen.dart` — filenames, previews, menu labels

**Effect:** two chats sitting next to each other (a DM and a group) render the sender/timestamp text at different weights and letter-spacing because one path used `AppFontWeight` and the other used a bare `FontWeight.w500`. It's subtle enough to not be "wrong" on any single screen, but it's the kind of drift users register as "this doesn't feel finished" without being able to say why.

### 1.2 Icons: Phosphor system undermined by stray Material icons

The app ships a real icon system — `PhosphorIcon` backed by SVGs in `SVGs/{thin,light,regular,bold,fill,duotone}/`, currently only `regular` is bundled in `pubspec.yaml`. It's used correctly almost everywhere via `PhosphorAssets`. But raw `Icon(Icons.*)` sneaks in for:

- Message action sheet (both `chat_screen.dart._showMessageActions` and `group_chat_screen.dart._showMessageActions`): `Icons.copy_outlined`, `Icons.delete_outline`, `Icons.delete_forever_outlined`
- Settings theme switch: `SegmentedButton` icons use `Icons.brightness_auto_outlined/light_mode_outlined/dark_mode_outlined` — on arguably the single most-used control in Settings
- Auth screen email field: `Icons.alternate_email_rounded` (while the password/username fields on the *same form* correctly use `PhosphorAssets.lock/user`)
- Group create/edit dialogs: `Icon(Icons.camera_alt_outlined)` avatar-upload overlay
- Group member management sheet: `Icons.shield_outlined`, `Icons.person_remove_outlined`, `Icons.more_horiz`
- Group details edit button: `Icons.edit_outlined`
- Group chat status ticks: `Icons.schedule/done/done_all` (see 1.3 — this one also duplicates logic)

**Effect:** two icon grammars (Phosphor's rounded-stroke line icons vs. Material's filled/outlined defaults) visibly clash mid-screen, most jarringly in the Settings appearance selector and the message long-press sheet, which is one of the highest-frequency interactions in the app.

### 1.3 Duplicated, drifting logic: DM bubble vs. group bubble

`chat_message_tile.dart` defines a shared `ChatMessageTile`/`_Bubble`/`_StatusIcon`/`_DateDivider` — a solid, reusable abstraction with enter-animation, three-state status ticks (pending/sent/read via `PhosphorAssets.clock`/`checks`), and day dividers.

`group_chat_screen.dart` does **not** reuse any of it. It hand-rolls `_GroupBubble` with:
- Copy-pasted bubble decoration (radius formula, shadow, border) instead of parameterizing `_Bubble`
- Its own two-state status logic using raw `Icon(Icons.schedule/done/done_all)` instead of the three-state `_StatusIcon`
- No date dividers at all (`sameChatDay`/`_DateDivider` never called)
- No enter animation
- Message-action bottom sheet copy-pasted verbatim from `chat_screen.dart` (same three `ListTile`s, same Material icons, same lack of drag-handle/header styling that the rest of the app's sheets have)

**Effect:** a real feature-parity gap (no date separators in groups) plus double-maintenance surface. This is the single highest-value refactor in the whole spec (§5.1, §6.5).

### 1.4 Radius, spacing, and "card" have no scale

Radius values in current use: `8, 9, 10, 12, 14, 15, 16, 18, 20, 22, 24, 28, 30`. Some are semantically deliberate (bubble tail `7`, pill badges `~half-height`), but most are just whatever felt right in that file. There is a themed `CardTheme` (radius 20, `surface`, `borderSoft` side) used via `Card()` in `profile_screen.dart`, `groups_screen.dart`, `group_details_screen.dart` — but most other "boxed content" (settings rows, server settings info box, log status bar, file attachment tile, context-menu preview card, conversation tile) hand-roll `Container(decoration: BoxDecoration(...))` with their own radius instead of reusing `Card` or a shared token.

**Effect:** no two "boxes" in the app share a corner radius unless by coincidence, which is very perceptible even to users who couldn't name the cause.

### 1.5 One polished screen, several flat ones

`auth_screen.dart` is by far the most art-directed surface: radial gradient backdrop, floating glass card, brand panel with feature chips, animated tab indicator. Every screen behind login (`settings_screen.dart`, `profile_screen.dart`, `groups_screen.dart`, `server_settings_screen.dart`) is a plain `ListView` of section labels and bordered rows with no equivalent visual ambition. That gap — genuinely great login screen, generic everything-after — is one of the most common "half-baked SaaS app" tells and is worth deliberately correcting (§6.9–§6.11), not just tidying.

### 1.6 Empty states: four different patterns for one job

- Conversations empty (`conversations_screen._emptyState`): `surfaceHigh` rounded-square icon box, no border
- Chat empty (`chat_screen._emptyState`): circular `accentSoft` icon badge
- Groups empty (`groups_screen.build`): bare icon, no container at all
- Desktop no-chat-selected (`home_shell._DesktopEmptyPane`): bordered box + accent-tinted shadow + `Image.asset` app icon, entirely different composition from the other three

No shared `EmptyState` widget exists; each was invented independently. (§5.2)

### 1.7 Bottom sheets: three ad-hoc re-implementations of "drag handle + header"

`_NewChatSheet` (conversations), `_GifPickerSheet` (chat_composer), `EmojiPickerSheet`, and `showConversationContextMenu`'s preview sheet each reimplement the 36×4 drag handle + rounded-top container, with different corner radii (16 vs 20), different backgrounds (`surfaceHigh` vs `surface` vs `transparent`→`surface`), and no shared header row treatment. The message-action sheet (§1.3) skips this pattern entirely and falls back to an undecorated `SafeArea(Column(ListTile...))`. (§5.3)

### 1.8 Controls that ignore the app's accent

`SwitchListTile`/`SwitchListTile.adaptive` in the group create/edit dialogs (`groups_screen._showCreateGroup`, `group_details_screen._editGroup`) use **default Material switch colors** (system green/blue depending on platform), while the one Settings switch (`settings_screen.dart`, notifications) is correctly themed (`activeThumbColor: Colors.white, activeTrackColor: c.accent`). In an app whose entire identity is a warm orange accent with 6 selectable palettes, a default-colored switch appearing inside a themed dialog is one of the more visible "someone forgot to finish this" signals.

### 1.9 Feature-parity gaps between DM and group surfaces

- Groups list tile (`groups_screen.dart`, plain `Card`+`ListTile`) has no unread badge, no last-message preview, no relative timestamp, no online indicator — all of which the DM `_ConversationTile` has.
- Groups tab has no search; Conversations tab does.
- Groups tab has no pull-to-refresh; Conversations tab does.
- These read as "the DM experience is the real product and Groups was bolted on," even though both are core features per the README.

### 1.10 Form field presentation is inconsistent

Floating `labelText` (auth screen, profile screen) vs. plain `hintText` (conversations search, new-chat sheet, GIF search, server settings) vs. `hintText` + `errorText` combined (new-chat sheet) — three different input idioms with no rule for which situation gets which. Helper/caption text under fields is sometimes `AppTheme.text(c, color: c.secondary, fontSize: 12)`, sometimes bare `TextStyle`, sometimes `Theme.of(context).textTheme.bodyMedium`.

### 1.11 Miscellaneous rough edges worth fixing in the same pass

- GIF picker sheet auto-searches the literal string `"hello"` on open — a leftover debugging default that a real user will notice as "why is it always showing hello gifs."
- Avatar-picking flow (profile, group create, group edit — three separate implementations) has no crop/preview step; it uploads immediately, and only the profile-screen one shows a spinner with reasonable placement.
- `_SectionLabel` is reimplemented identically in `settings_screen.dart` and `profile_screen.dart` (and `server_settings_screen._label` is a fourth near-duplicate).
- No skeleton/shimmer loading anywhere — every loading state is a centered `CircularProgressIndicator`, which under-delivers relative to the polish elsewhere (message enter-animation, themed cross-fade on theme switch).
- Binary `isWideLayout` breakpoint means there's no tuned behavior for in-between (tablet/split-screen) widths — it's mobile-stack or full desktop master-detail with nothing between.
- Six icon *weights* ship in `SVGs/` (`thin/light/regular/bold/fill/duotone`) but only `regular` is ever used and only `regular` is bundled as an asset — there's an easy, currently-unused win here (§4.3): filled icons for *selected* nav/tab state, exactly like iOS does, instead of only a color change.

---

## 2. Design principles for this redesign

1. **One token, one meaning, everywhere.** If a screen needs "secondary caption text," it calls `AppTheme.text(c, color: c.secondary, fontSize: 12)` (or a new named helper — §4.1) — never a bare `TextStyle`. No exceptions, no "just this once."
2. **Phosphor or nothing.** Every `Icon(...)`/`Icons.*` in `lib/` is replaced with `PhosphorIcon(PhosphorAssets.*)`. If a needed glyph doesn't exist in `PhosphorAssets`, add the mapping (the SVGs likely already exist under `SVGs/regular/` — check before assuming a new asset is needed).
3. **Build the shared widget once, use it five times** — not five ad-hoc versions of the same idea. §5 is the component inventory; nothing in §6 should be implemented "inline" if it's listed there.
4. **DM and group surfaces are the same feature with a different data source.** Anywhere the two currently diverge without a real reason (bubble rendering, status ticks, date dividers, list-tile richness, message actions), unify on one implementation parameterized by conversation type.
5. **Raise the floor, don't lower the ceiling.** The auth screen's polish is the *bar*, not an outlier to sand down. Settings/Profile/Groups should be brought up to that level of intentionality (real section compositions, not just "ListView of labeled rows"), not have the auth screen simplified to match them.
6. **No new backend requirements.** Every visual improvement must work with data `AppState` already exposes. Anything that would need a new endpoint (message reactions, typing indicators, edit history) goes in §12 as a flagged future option, not into this pass.
7. **Motion is a token too.** Durations/curves get named constants (§4.4) instead of the current mix of literal `Duration(milliseconds: 150/160/180/200/260)` scattered per-widget with no naming.

---

## 3. Foundation layer — `theme.dart` additions

Extend `theme.dart` (do not replace what's already good — `AppColors`, `AppFontWeight`, `AppTheme.text/heading/appBarTitle/display/sectionLabel` all stay exactly as they are).

### 3.1 Radius scale

```dart
abstract final class AppRadius {
  static const xs = 8.0;   // small chips, inline pills
  static const sm = 12.0;  // form fields, small buttons, list rows
  static const md = 16.0;  // standard containers, dialogs-in-content
  static const lg = 20.0;  // cards (matches existing CardThemeData), message bubbles' rounded corners
  static const xl = 28.0;  // sheets, dialogs, hero containers
  static const tail = 7.0; // message-bubble tail corner (keep as a named exception, not a magic number)
}
```
Audit every hardcoded `BorderRadius.circular(N)` in `lib/` and replace `N` with the nearest tier above. Where a value doesn't cleanly map (e.g. the auth card's `28`, the brand icon's `30`), pick the nearest tier and accept the small visual delta — consistency wins over preserving an arbitrary number.

### 3.2 Spacing scale

```dart
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}
```
Not a hard requirement to replace every `SizedBox(height: N)` in the app (that would be enormous, low-value churn), but **new/rewritten code in this pass must use these constants**, and any padding inside a component listed in §5 must use them.

### 3.3 Icon weight policy

Add `regular` (default, current), plus bundle `fill` for selected states:

```yaml
# pubspec.yaml
assets:
  - assets/icon/app_icon.png
  - SVGs/regular/
  - SVGs/fill/
```

`PhosphorIcon` gains a `weight` param defaulting to `regular`:

```dart
class PhosphorIcon extends StatelessWidget {
  const PhosphorIcon(this.name, {this.weight = PhosphorWeight.regular, ...});
  static String assetPath(String name, PhosphorWeight weight) =>
      'SVGs/${weight.folder}/$name.svg';
}
enum PhosphorWeight { thin, light, regular, bold, fill, duotone }
```

Use `fill` for: selected `NavigationBar`/`NavigationRail` destination icon, selected bottom-sheet tab, active `_loginChip`/palette selection indicator — anywhere the app currently signals "selected" with color alone, it should also swap outline→fill, matching the iOS/Phosphor convention the asset set was clearly bundled to support.

### 3.4 Motion tokens

```dart
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);   // icon/opacity micro-transitions
  static const base = Duration(milliseconds: 180);   // standard UI transitions
  static const enter = Duration(milliseconds: 220);  // message/element enter animations
  static const theme = Duration(milliseconds: 260);  // theme cross-fade (matches existing main.dart value)
  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutBack; // for playful pops (send button scale, etc.)
}
```
Replace literal `Duration(milliseconds: ...)` across all widgets with these.

### 3.5 Elevation / shadow tokens

Two shadow "levels" cover every current use (card hover/press, floating sheets, auth card, FAB):

```dart
abstract final class AppShadow {
  static List<BoxShadow> level1(AppColors c) => [
        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
      ];
  static List<BoxShadow> level2(AppColors c) => [
        BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 32, offset: const Offset(0, 14)),
      ];
  static List<BoxShadow> accentGlow(AppColors c) => [
        BoxShadow(color: c.accent.withValues(alpha: 0.18), blurRadius: 36),
      ];
}
```

---

## 4. Shared component library (build these once, in `lib/widgets/`, before touching individual screens)

Each of these replaces 2+ current ad-hoc implementations. Build and unit/widget-test these first — every screen spec in §6 assumes they exist.

### 4.1 `AppText` helper additions (in `theme.dart`, not a new widget)
Add the missing tokens callers keep faking with raw `TextStyle`:
```dart
static TextStyle caption(AppColors c, {Color? color}) =>
    text(c, color: color ?? c.secondary, fontSize: 12, wght: 450, height: 1.35);
static TextStyle listTitle(AppColors c, {bool emphasized = false}) =>
    text(c, fontSize: 15, wght: emphasized ? AppFontWeight.semibold : AppFontWeight.medium, height: 1.2);
static TextStyle timestamp(AppColors c, {Color? color}) =>
    text(c, color: color ?? c.tertiary, fontSize: 11, height: 1.2);
```
This directly kills the largest source of drift in §1.1 — most raw `TextStyle` call sites map onto one of these three.

### 4.2 `EmptyState` widget
```dart
class EmptyState extends StatelessWidget {
  final String icon;         // PhosphorAssets.*
  final String title;
  final String? message;
  final Widget? action;      // optional button
  final EmptyStateStyle style; // .badge (circular accentSoft) | .tile (rounded surfaceHigh square)
}
```
One composition, one icon-container treatment (pick the `chat_screen._emptyState` circular-badge version — it reads as the friendliest), used by: conversations empty, chat empty, groups empty, group-chat empty, desktop no-selection pane, no-search-results state. Desktop pane keeps its extra "New chat" button via the `action` slot; nothing else needs a bespoke composition.

### 4.3 `AppBottomSheet` scaffold
```dart
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions; // optional trailing header actions (e.g. close button)
  static Future<T?> show<T>(BuildContext context, {String? title, required WidgetBuilder builder});
}
```
Owns: drag handle, corner radius (`AppRadius.xl`), background (`c.surface`), optional title row with close affordance, safe-area + keyboard-inset padding. Replaces the bespoke sheet chrome in `_NewChatSheet`, `_GifPickerSheet`, `EmojiPickerSheet`, and the conversation-context-menu preview sheet. On desktop (`isWideLayout`), `AppBottomSheet.show` should route to a centered `Dialog` instead (mirroring what `ConversationsScreen.showNewChatModal` already does) — bake that platform switch into this one helper so every future sheet gets it for free instead of re-deciding per call site.

### 4.4 `MessageActionSheet`
```dart
Future<void> showMessageActionSheet(
  BuildContext context, {
  required bool canCopy,
  required bool canDeleteForMe,
  required bool canDeleteForEveryone,
}) => ... // returns via callback or Future<MessageAction?>
```
Built on `AppBottomSheet`, using `PhosphorIcon`s (`copy` → check/add asset if missing, `trash`, `trash-simple` or similar — verify against `SVGs/regular/`) instead of `Icons.copy_outlined` etc. Used identically by `chat_screen.dart` and `group_chat_screen.dart` — deletes both hand-rolled copies (§1.3).

### 4.5 `SectionLabel`
Move the existing `_SectionLabel` (identical in `settings_screen.dart`/`profile_screen.dart`) into `lib/widgets/section_label.dart` as a public `SectionLabel`, delete both private copies.

### 4.6 `SurfaceCard`
A thin wrapper standardizing "boxed content" so nobody hand-rolls `Container(decoration: BoxDecoration(color: c.surface, ...))` again:
```dart
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius; // defaults AppRadius.lg
  final bool useCardTheme; // true => Card(), false => Container border (for nested/tighter contexts)
}
```
Replaces the hand-rolled containers in: settings rows, server-settings info box, log-status-bar collapsed card, file-attachment tile, context-menu preview card, `_InfoSection` boxes, groups list card.

### 4.7 `AvatarPicker`
```dart
class AvatarPicker extends StatefulWidget {
  final String? currentFileId;
  final String fallbackInitials;
  final double radius;
  final Future<String?> Function() onPick; // wraps AppState.uploadAvatarImage
  final ValueChanged<String> onPicked;
}
```
One implementation of "avatar + camera badge + upload spinner + tap target," replacing the three near-duplicates in `profile_screen.dart`, `groups_screen._showCreateGroup`, `group_details_screen._editGroup`. Internally still just calls `UserAvatar` — this only unifies the *badge/spinner/tap* chrome around it.

### 4.8 `ChatBubble` (the big one — see §5 below for full spec)

### 4.9 `AppSwitch`
A themed wrapper so no call site can accidentally get the default Material switch colors again:
```dart
Widget appSwitch(BuildContext context, {required bool value, required ValueChanged<bool> onChanged}) =>
    Switch(value: value, onChanged: onChanged, activeThumbColor: Colors.white, activeTrackColor: context.mc.accent, ...);
```
Replace every `Switch`/`SwitchListTile`/`SwitchListTile.adaptive` construction with this, including the two group dialogs currently using un-themed defaults (§1.8).

### 4.10 `LoadingButton`
Wraps the "swap label for a spinner while `loading`" pattern currently copy-pasted in `auth_screen._PrimaryAction`, `profile_screen`'s save button, `server_settings_screen._loadingButton`:
```dart
class LoadingButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined; // for secondary actions
}
```

---

## 5. Unify DM and group chat rendering

This is the highest-value single change (§1.3, §1.9). Target architecture:

```dart
class ChatBubble extends StatelessWidget {
  final String? text;
  final String? fileId;
  final bool isMe;
  final DateTime createdAt;
  final MessageStatus status;      // enum: pending | sent | read  (map group's readBy.isNotEmpty accordingly)
  final String? senderLabel;       // null for DM; peer display name for group, non-me messages only
  final bool animate;
  final VoidCallback? onLongPress;
  final AppColors colors;
  final double maxWidth;
}
```

- `chat_message_tile.dart`'s `_Bubble`, `_StatusIcon`, `_DateDivider`, and the enter-animation wrapper become the *only* bubble implementation. `ChatMessageTile` becomes a thin adapter for DM `Message`; add a `GroupChatMessageTile` adapter (or a single generic adapter taking already-extracted fields) that maps `GroupMessage` → the same `ChatBubble`, adding `senderLabel` when `!isMe`.
- Group chat gains date dividers for free (call `sameChatDay`/date-divider logic from the shared file — currently private to `chat_message_tile.dart`; make the divider public or expose a `shouldShowDateDivider(previous, current)` helper).
- Group status ticks upgrade from 2-state to the existing 3-state `_StatusIcon` (pending/delivered/read-by-all — for groups, treat "read" as `readBy.isNotEmpty`, matching current behavior, just via the shared widget instead of duplicated `Icon(Icons.*)` logic).
- Group chat gains the same enter-animation as DM chat.
- Both `chat_screen.dart` and `group_chat_screen.dart` call the same `showMessageActionSheet` (§4.4) instead of two copies of the same three-item bottom sheet.

**Needs data check:** none — `GroupMessage` already exposes `senderId`, `text`, `fileId`, `createdAt`, `readBy`, `uuid`; nothing here requires a new field.

---

## 6. Screen-by-screen spec

For each screen: **keep**, **fix**, **new**. "Keep" items are explicitly called out so the agent doesn't second-guess working code.

### 6.1 App shell & navigation (`main.dart`, `home_shell.dart`)

**Keep:** theme cross-fade, `AppLifecycleBridge`, bootstrap/session-check scaffolding, the mobile-stack vs. desktop-rail split, keyboard shortcuts (`Intents`).

**Fix:**
- Replace the three literal `Duration`s in `main.dart`/`home_shell.dart` with `AppMotion.theme`/`AppMotion.base`.
- `NavigationBar`/`NavigationRail` destination icons: use `PhosphorWeight.fill` when selected (§3.3) instead of relying on the existing color-only `iconTheme.resolveWith`.
- `_DesktopEmptyPane` → rebuild on `EmptyState` (§4.2) with its `action` slot holding the existing "New chat" `FilledButton.icon`.

**New:**
- Tune the wide-layout breakpoint: currently `isWideLayout` is binary. Add a middle tier (roughly 700–980px) where the rail's `NavigationRailLabelType` drops to `.selected` (icon-only otherwise) and the conversation list column narrows to ~300px instead of the fixed 370px, so a tablet-portrait or a half-tiled desktop window doesn't feel cramped. (Check `lib/utils/platform_ui.dart` for where `isWideLayout` lives and add the intermediate check there.)

### 6.2 Auth (`auth_screen.dart`)

**Keep:** everything — this is the bar (§2.5). Gradient backdrop, brand panel, floating card, tab switcher, feature chips.

**Fix (small, consistency-only):**
- Replace `Icon(Icons.alternate_email_rounded)` on the email field with a `PhosphorAssets` equivalent (check for `at`/`envelope` in `SVGs/regular/`; add to `PhosphorAssets` if present but unmapped).
- `_PrimaryAction` → replace with `LoadingButton` (§4.10).
- Route the `_ErrorNotice` styling into a shared `InlineNotice` if one doesn't already exist elsewhere with the same shape (check §6.11's server-settings error notice — likely worth unifying into one `InlineNotice(level: error|info|warning)` used by both).

### 6.3 Conversations list (`conversations_screen.dart`)

**Keep:** search-in-app-bar pattern, `RefreshIndicator`, `_ConversationTile`'s rich layout (avatar+online-dot, unread bold, relative timestamp, unread badge, chevron).

**Fix:**
- `_ConversationTile`, `_UnreadBadge`, `_NewChatSheet`: replace every raw `TextStyle` with `AppTheme.listTitle`/`caption`/`timestamp` (§4.1).
- `_NewChatSheet` → rebuild on `AppBottomSheet` (§4.3); keep its content (online-contacts chip row + username/email/ID field) unchanged.
- Empty state and no-results state → `EmptyState`.

**New:**
- Nothing structural — this screen is close to right; it's the *reference* other list screens (Groups) should be brought up to.

### 6.4 Chat screen — DM (`chat_screen.dart`)

**Keep:** scroll-to-bottom FAB logic, connection/upload banners, message fingerprinting for selective rebuilds, embedded/standalone dual mode.

**Fix:**
- `_showMessageActions` → `showMessageActionSheet` (§4.4).
- `_emptyState` → `EmptyState`.
- Confirm `ChatMessageTile` now delegates fully to the shared `ChatBubble` (§5).

**New:** none required; this screen's bones are correct.

### 6.5 Group chat (`group_chat_screen.dart`)

**Fix (the big one, per §5):**
- Delete `_GroupBubble` entirely; route through the shared `ChatBubble` with `senderLabel` set for non-`isMe` messages.
- Add date dividers (currently absent).
- Upgrade status ticks to the 3-state shared `_StatusIcon`.
- Add the same enter-animation DM chat has.
- `_showMessageActions` → `showMessageActionSheet`.
- `_showAddMember` dialog and the leave-group confirm dialog: audit for raw `TextStyle`/`Icons.*` (currently clean of `Icons.*` but check text styling).

**New:**
- Empty state → `EmptyState` (currently a bespoke `accentSoft` box; fine visually, just route through the shared widget so future tweaks apply everywhere).

### 6.6 Groups list (`groups_screen.dart`)

**Fix:**
- Rebuild the list tile to match `_ConversationTile`'s richness: online/member-count subtitle already partially there, but add **unread badge** and **last-activity relative time** to bring it to parity with Conversations (§1.9). *Needs data check:* confirm `AppState` exposes an unread count / last-message getter for groups analogous to `getUnreadCount`/`getLastMessage` for peers — if it doesn't yet, this is the one place in this spec that may need a small `AppState` addition (a getter over already-fetched `GroupMessage` history, not a new backend endpoint); if truly unavailable, ship without the badge rather than block on it.
- Add a search field in the app bar, matching Conversations' pattern exactly (same `TextField` decoration, same clear-button behavior).
- Add `RefreshIndicator` calling the existing group-list refresh path (mirror `conversations_screen`'s `chat.listConnections()` call with whatever the group equivalent is).
- Replace the plain `Card`+`ListTile` with a tile built the same way as `_ConversationTile` (shared avatar+online-dot composition where "online" for a group can reasonably be omitted or replaced with member-count).
- `_showCreateGroup` avatar picker → `AvatarPicker` (§4.7); switches → `appSwitch` (§4.9); camera icon → `PhosphorIcon`.
- Empty state → `EmptyState`.

### 6.7 Group details (`group_details_screen.dart`)

**Fix:**
- `_editGroup` avatar picker → `AvatarPicker`; switches → `appSwitch`; `Icons.camera_alt_outlined`/`Icons.edit_outlined` → `PhosphorIcon`.
- `_memberAction` sheet: `Icons.shield_outlined`/`Icons.person_remove_outlined` → `PhosphorIcon`; route through `AppBottomSheet` for consistent chrome.
- `_MemberTile`'s trailing `Icons.more_horiz` → `PhosphorIcon`.
- Member list card → `SurfaceCard`.

### 6.8 Profile — own (`profile_screen.dart`) and peer (`user_profile_screen.dart`)

**Fix:**
- Both screens: dedupe `_SectionLabel` → shared `SectionLabel` (§4.5); dedupe `_InfoSection`-style value boxes → `SurfaceCard`.
- `profile_screen`'s inline avatar-camera-badge → `AvatarPicker`.
- Replace raw `TextStyle` on display name/`@username`/bio/info values with `AppTheme.listTitle`/`caption`/tokens.
- Save button → `LoadingButton`.

**New (raising these off the "flat ListView" floor per §2.5, §1.5):**
- Give the profile header its own visual identity instead of a bare `Card`: a subtle top gradient/tint strip behind the avatar (reusing the auth screen's radial-gradient recipe at a much lower alpha, e.g. `c.accent.withValues(alpha: 0.06)`) so this screen doesn't read as "the one screen with no art direction." Keep it restrained — this is a settings-adjacent screen, not a marketing screen — but it should not look like the exact same recipe as Server Settings.
- On `user_profile_screen`, if the peer is a shared-group contact, consider surfacing shared-group chips (only if `AppState` already has this relationship data available cheaply — otherwise skip; do not add a new lookup for this).

### 6.9 Settings (`settings_screen.dart`)

**Fix:**
- Theme-mode `SegmentedButton` icons: `Icons.brightness_auto_outlined/light_mode_outlined/dark_mode_outlined` → `PhosphorIcon` equivalents (check `SVGs/regular/` for `circle-half`, `sun`, `moon` or similar; add to `PhosphorAssets` if unmapped).
- `_NavTile`/`_PaletteChip` raw `TextStyle` → tokens.
- Notification `SwitchListTile` → `appSwitch` (already close to correct — just route through the shared helper for consistency, not because it's currently broken).
- Rows (`_NavTile`, palette chip container, notification container, diagnostics container) → `SurfaceCard` where it doesn't change their current bordered-row look, just centralizes it.
- `_SectionLabel` → shared `SectionLabel`.

**New:**
- The **Appearance** section is this app's most distinctive feature (6 accent palettes) and currently gets the same flat treatment as every other row. Give the palette picker a slightly larger, more tactile presentation: bigger swatches (not just a 26×18 gradient chip), perhaps a short live-preview strip (a tiny mock bubble pair in the selected palette) above the chip row, so choosing a palette feels like the highlight feature it is rather than one setting among many.

### 6.10 Server settings (`server_settings_screen.dart`)

**Fix:**
- Replace `Theme.of(context).textTheme.bodyMedium` caption usage with `AppTheme.caption` (§4.1) — this is the one screen using a *third* text-styling pattern.
- `_infoBox` → could become the shared `InlineNotice(level: info)` mentioned in §6.2.
- `_loadingButton` → `LoadingButton`.
- `_label` → shared `SectionLabel`.
- Ping-result rows → `SurfaceCard` if it doesn't fight the existing `OutlinedButton.icon` + result-text layout; otherwise leave the layout, just fix text tokens.

### 6.11 Cross-cutting overlays

- **Emoji picker sheet** (`emoji_picker_sheet.dart`): rebuild its header (title + close button) on `AppBottomSheet`'s title-row API instead of hand building the drag-handle+row again. Keep the `EmojiPicker` config as-is — it's already correctly themed via passed-in colors.
- **GIF picker sheet** (`chat_composer._GifPickerSheet`): same — route through `AppBottomSheet`. Remove the hardcoded `'hello'` default query (§1.11); show an empty/prompt state ("Search for a GIF") until the user types, or — if a "trending" Tenor endpoint is trivially available in `GifSearchService` already — use that instead of a canned keyword. Do not invent a new Tenor call if the service doesn't already support it; the safe fallback is just an empty prompt state.
- **Conversation context menu** (`conversation_context_menu.dart`): preview-card sheet → `AppBottomSheet`; desktop `showMenu` path can stay as native context menu (that's the correct desktop idiom, don't over-engineer it).
- **Log status bar** (`log_status_bar.dart`): mostly consistent already; route its collapsed "no entries" card and expanded header through `SurfaceCard`/tokens for completeness, low priority.

---

## 7. Motion & micro-interaction notes

- Standardize all "tap → subtle scale" feedback (send button already does this) using `AppMotion.fast` + `AppMotion.emphasized` — apply the same treatment to: palette chip selection, new-chat "Start" button, avatar-picker camera badge on tap.
- Message enter-animation (`_MessageEnterAnimation`) becomes shared (§5) — verify it looks correct for both left- and right-aligned bubbles once used by group chat too (it already parameterizes on `isMe`, so this should be free).
- Keep the existing theme-mode cross-fade animation (`themeAnimationDuration`/`themeAnimationCurve` in `main.dart`) exactly as is — it's one of the nicer existing touches — just rename the literal to `AppMotion.theme`.

## 8. Accessibility & responsiveness

- Every `PhosphorIcon` used as a standalone tappable control (not decorative, e.g. inside a labeled button) must have a `tooltip`/`semanticLabel` — audit current `IconButton`s for missing `tooltip` (several already have it; a few, e.g. some `PopupMenuButton` triggers, don't).
- Verify minimum tap targets stay ≥44×44 after any radius/padding token swap — the `AppRadius`/`AppSpace` substitution in §3 must not shrink any interactive element below its current effective hit area.
- Re-check text contrast on the palette-picker swatches and the accent-tinted profile header background (§6.8) in both light and dark mode, and across all 6 accent presets, not just the default "Autumn" — this is the one part of the spec most likely to accidentally fail contrast on an unusual palette (e.g. "Moss," which is lower-chroma).
- `isWideLayout` middle-tier addition (§6.1) should be verified at common breakpoints: 768px (iPad portrait split), 834px (iPad landscape split), ~900–1000px (small laptop windowed).

## 9. Non-goals / constraints

- No changes to `lib/services/*`, `lib/models/*`, or the WebSocket/HTTP wire format.
- No new backend endpoints. Every "New" item above must work with data already reachable from `AppState`; where it might not be (flagged inline), degrade gracefully rather than block.
- No new third-party packages beyond what's already in `pubspec.yaml`, unless a specific `PhosphorAssets` glyph is genuinely missing from the bundled SVG set (check before adding anything).
- Must keep `flutter analyze` clean and `flutter test` passing at every step — this is a large refactor touching nearly every screen; do it incrementally (§10) and keep the app buildable after each phase.
- Don't rename existing public `AppState`/service APIs even if a slightly different name would read better — this is a UI-only pass.

## 10. Suggested implementation order

1. **Foundation** (§3): `AppRadius`, `AppSpace`, `AppMotion`, `AppShadow`, `AppText` additions, `PhosphorWeight`/`fill` asset bundling. Zero visual change yet, just infrastructure.
2. **Shared components** (§4): `EmptyState`, `AppBottomSheet`, `MessageActionSheet`, `SectionLabel`, `SurfaceCard`, `AvatarPicker`, `appSwitch`, `LoadingButton`, `InlineNotice`. Build with a throwaway test harness screen if useful, but don't wire into real screens yet.
3. **Chat unification** (§5): the `ChatBubble` refactor. This is the riskiest/highest-value change — do it in isolation, verify both DM and group chat visually and via `flutter test`, before moving on.
4. **Screen-by-screen sweep** (§6), roughly in this order: Conversations → Chat (DM) → Group chat → Groups list → Group details → Profile (own) → Profile (peer) → Settings → Server settings → Auth (smallest touch) → cross-cutting overlays.
5. **Motion/a11y/responsive pass** (§7–§8) as a final sweep across everything touched above.

## 11. Definition of done

- [ ] Zero raw `TextStyle(...)` construction remains in `lib/screens/` or `lib/widgets/` outside of `theme.dart` itself (grep for `TextStyle(` and account for every hit).
- [ ] Zero `Icon(Icons.` remains in `lib/` (grep for `Icons\.` and account for every hit; `Icon(` wrapping a `PhosphorIcon` internal implementation detail is fine, but no call site outside `phosphor_icon.dart` constructs a Material `Icon`).
- [ ] Every corner radius in touched files maps to an `AppRadius` tier.
- [ ] `group_chat_screen.dart` has no bubble-rendering code of its own — it calls the shared `ChatBubble`.
- [ ] DM and group chats have identical status-tick logic, date-diViders, and message-action sheets.
- [ ] Groups list has search, unread badges (if data allows), and pull-to-refresh, matching Conversations.
- [ ] No `SwitchListTile`/`Switch` anywhere renders with default (un-themed) colors.
- [ ] GIF picker no longer auto-searches `"hello"`.
- [ ] `flutter analyze` and `flutter test` pass.
- [ ] Manually verified in both light and dark mode, and in at least 2 of the 6 accent palettes beyond the default.
- [ ] Manually verified at mobile width, the new tablet-tier width, and full desktop width.

## 12. Open questions for product (not blocking — flag, don't guess)

- Should Groups and Conversations become one unified "Chats" list (DMs + groups + channels sorted by recency), or stay as separate tabs with Groups brought up to visual parity as specified in §6.6? This spec assumes **separate tabs, parity in richness** — the lower-risk option — but a unified list is the more modern IA pattern if product wants to revisit it later.
- Message reactions, typing indicators, and edit/edit-history are conspicuously absent and would meaningfully modernize the chat feel, but all require new backend support and are explicitly out of scope here (§9). Worth a separate spec once/if the backend adds them.
- Whether "online" status should be shown on group tiles as an aggregate ("3 online") instead of omitted, per §6.6 — left as an omission for now pending confirmation `AppState` can cheaply compute it.
