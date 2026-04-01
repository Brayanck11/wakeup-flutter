import 'package:flutter/services.dart';

/// Escucha eventos de alarma disparados desde Android (AlarmReceiver)
class AlarmEventService {
  static const _eventChannel = EventChannel('com.wakeup.alarm/alarm_events');

  /// Stream de eventos de alarma. Cada evento es un Map con:
  /// - label: String
  /// - sound: String
  /// - gradual: bool
  /// - id: int
  static Stream<Map<String, dynamic>> get alarmStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }
}
