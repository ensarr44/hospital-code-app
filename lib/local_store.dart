// lib/local_store.dart
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_code_app/main.dart';

class LocalStore {
  // ---- session keys
  static const _kEmail = 'session_email';
  static const _kMode = 'session_mode';

  // ---- settings keys
  static const _kSettingsJson = 'settings_json';

  // ============ SESSION ============
  static Future<void> saveSession({
    required String email,
    required AppMode mode,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kEmail, email);
    await sp.setString(_kMode, mode.name);
  }

  static Future<({String email, AppMode mode})?> readSession() async {
    final sp = await SharedPreferences.getInstance();
    final email = sp.getString(_kEmail);
    final modeStr = sp.getString(_kMode);

    if (email == null || email.isEmpty || modeStr == null || modeStr.isEmpty) {
      return null;
    }

    final mode = AppMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => AppMode.personal,
    );

    return (email: email, mode: mode);
  }

  static Future<void> clearSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kEmail);
    await sp.remove(_kMode);
  }

  // ============ SETTINGS (JSON) ============
  /// Ayarları Map olarak kaydet
  static Future<void> saveSettings(Map<String, dynamic> data) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSettingsJson, jsonEncode(data));
  }

  /// Kaydedilmiş ayarları Map olarak oku
  static Future<Map<String, dynamic>?> readSettings() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSettingsJson);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSettings() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kSettingsJson);
  }
}
