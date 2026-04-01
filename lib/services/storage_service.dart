import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm.dart';

class StorageService {
  static const _alarmsKey = 'wu_alarms';
  static const _histKey = 'wu_history';
  static const _statsKey = 'wu_stats';

  static Future<List<Alarm>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_alarmsKey);
    if (str == null) return [];
    final List list = jsonDecode(str);
    return list.map((e) => Alarm.fromJson(e)).toList();
  }

  static Future<void> saveAlarms(List<Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alarmsKey, jsonEncode(alarms.map((a) => a.toJson()).toList()));
  }

  static Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_histKey);
    if (str == null) return [];
    final List list = jsonDecode(str);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_histKey, jsonEncode(history));
  }

  static Future<Map<String, dynamic>> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_statsKey);
    if (str == null) return {'snooze': 0, 'dismiss': 0, 'cc': {}};
    return jsonDecode(str);
  }

  static Future<void> saveStats(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats));
  }
}
