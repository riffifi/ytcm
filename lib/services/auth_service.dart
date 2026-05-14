import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AuthService {
  final String baseUrl;

  AuthService({this.baseUrl = 'http://127.0.0.1:3000'});

  Future<String?> login({
    required String loginDetails,
    required String password,
    String loginType = 'email',
    int liveTime = 86400,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login_type': loginType,
          'login_details': loginDetails,
          'password': password,
          'live_time': liveTime,
        }),
      );
      if (res.statusCode == 200) return res.body.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/adduser').replace(queryParameters: {
        'username': username,
        'email': email,
        'password': password,
        'phone_number': phoneNumber,
      });
      final res = await http.get(uri);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<UserInfo?> getSessionInfo(String token) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/sessionuserinfo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_tocken': token}),
      );
      if (res.statusCode == 200) {
        return UserInfo.fromSessionJson(jsonDecode(res.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<UserInfo?> getUserInfo(String token, String username) async {
    try {
      final uri = Uri.parse('$baseUrl/getuserinfo').replace(queryParameters: {
        'session_tocken': token,
        'username': username,
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final info = await getSessionInfo(token);
        return UserInfo.fromProfileJson(jsonDecode(res.body), info?.uuid ?? '');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setOnline(String token) async {
    try {
      await http.get(Uri.parse('$baseUrl/online?session_tocken=$token'));
    } catch (_) {}
  }

  Future<void> setOffline(String token) async {
    try {
      await http.get(Uri.parse('$baseUrl/offline?session_tocken=$token'));
    } catch (_) {}
  }

  Future<bool> changeUsername(String token, String newUsername) async {
    try {
      final uri = Uri.parse('$baseUrl/changeusername').replace(queryParameters: {
        'session_tocken': token,
        'new_value': newUsername,
      });
      final res = await http.get(uri);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeFirstName(String token, String value) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/changefirstname'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_tocken': token, 'new_value': value}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeLastName(String token, String value) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/changelastname'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_tocken': token, 'new_value': value}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
