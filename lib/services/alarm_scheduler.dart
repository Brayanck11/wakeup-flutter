import 'package:flutter/services.dart';
import '../models/alarm.dart';

class AlarmScheduler {
  static const _channel = MethodChannel('com.wakeup.alarm/alarm_manager');

  /// Programa una alarma real en el sistema Android
  static Future<void> schedule(Alarm alarm) async {
    final now = DateTime.now();
    DateTime trigger = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);

    // Si la hora ya pasó hoy, programar para mañana
    if (trigger.isBefore(now)) {
      trigger = trigger.add(const Duration(days: 1));
    }

    // Si tiene días específicos, buscar el próximo día correcto
    if (alarm.days.isNotEmpty) {
      trigger = _nextOccurrence(alarm.hour, alarm.minute, alarm.days);
    }

    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'id': alarm.id % 100000, // Android limita el ID
        'triggerMs': trigger.millisecondsSinceEpoch,
        'label': alarm.label,
        'sound': alarm.sound,
        'gradual': alarm.gradual,
      });
    } catch (e) {
      print('Error programando alarma: $e');
    }
  }

  /// Cancela una alarma del sistema
  static Future<void> cancel(Alarm alarm) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {'id': alarm.id % 100000});
    } catch (e) {
      print('Error cancelando alarma: $e');
    }
  }

  /// Detiene el servicio de alarma sonando
  static Future<void> stopAlarmService() async {
    try {
      await _channel.invokeMethod('stopAlarmService');
    } catch (e) {}
  }

  /// Pide permiso para ignorar optimización de batería
  static Future<void> requestBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimization');
    } catch (e) {}
  }

  /// Pide permiso para alarmas exactas (Android 12+)
  static Future<void> requestExactAlarm() async {
    try {
      await _channel.invokeMethod('requestExactAlarm');
    } catch (e) {}
  }

  /// Verifica el estado de los permisos
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      return Map<String, bool>.from(result as Map);
    } catch (e) {
      return {'notifications': false, 'exactAlarm': false, 'batteryOptimization': false};
    }
  }

  static DateTime _nextOccurrence(int hour, int minute, List<int> days) {
    final now = DateTime.now();
    for (int i = 0; i < 8; i++) {
      final candidate = DateTime(now.year, now.month, now.day, hour, minute)
          .add(Duration(days: i));
      final dayIdx = (candidate.weekday - 1) % 7; // 0=Lu
      if (days.contains(dayIdx) && candidate.isAfter(now)) {
        return candidate;
      }
    }
    return DateTime.now().add(const Duration(minutes: 1));
  }
}
