import 'package:shared_preferences/shared_preferences.dart';

/// Small pieces of state shared between the UI and WorkManager isolates.
class BackgroundState {
  static const appInForegroundKey = 'app_in_foreground';
  static const activeChatPeerKey = 'active_chat_peer';
  static const notifiedMessageIdsKey = 'notified_message_ids';

  static Future<void> updateAppState({
    required bool inForeground,
    String? activeChatPeerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(appInForegroundKey, inForeground);
    if (activeChatPeerId != null && activeChatPeerId.isNotEmpty) {
      await prefs.setString(activeChatPeerKey, activeChatPeerId);
    } else {
      await prefs.remove(activeChatPeerKey);
    }
  }

  static Future<SharedPreferences> freshPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static bool alreadyNotified(
    SharedPreferences prefs,
    String messageUuid,
  ) =>
      (prefs.getStringList(notifiedMessageIdsKey) ?? const [])
          .contains(messageUuid);

  static Future<void> markNotified(
    SharedPreferences prefs,
    String messageUuid,
  ) async {
    await prefs.reload();
    final ids = prefs.getStringList(notifiedMessageIdsKey) ?? <String>[];
    if (ids.contains(messageUuid)) return;
    ids.add(messageUuid);
    if (ids.length > 300) {
      ids.removeRange(0, ids.length - 300);
    }
    await prefs.setStringList(notifiedMessageIdsKey, ids);
  }
}
