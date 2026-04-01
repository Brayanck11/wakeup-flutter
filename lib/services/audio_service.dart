import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isPlaying = false;

  // Tonos del sistema Android (URIs estándar)
  static const Map<String, String> systemRingtones = {
    'beep': 'android.resource://com.wakeup.alarm/raw/beep',
    'default_ringtone': 'content://settings/system/ringtone',
    'default_alarm': 'content://settings/system/alarm_alert',
    'default_notification': 'content://settings/system/notification_sound',
  };

  static const _channel = MethodChannel('com.wakeup.alarm/ringtone');

  /// Reproduce un tono — puede ser URI del sistema o ruta de archivo
  static Future<void> play(String soundId, {bool loop = true}) async {
    await stop();
    _isPlaying = true;

    try {
      if (soundId.startsWith('/') || soundId.startsWith('file://')) {
        // Es un archivo MP3 del almacenamiento
        final path = soundId.replaceFirst('file://', '');
        await _player.play(DeviceFileSource(path));
      } else if (soundId.startsWith('content://') || soundId.startsWith('android.resource://')) {
        // Es un URI del sistema Android — usar canal nativo
        await _playSystemSound(soundId);
      } else {
        // Tono predeterminado de alarma del sistema
        await _playSystemSound('content://settings/system/alarm_alert');
      }

      if (loop) {
        _player.onPlayerComplete.listen((_) async {
          if (_isPlaying) await _player.resume();
        });
      }
    } catch (e) {
      // Fallback: vibrar
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> _playSystemSound(String uri) async {
    try {
      await _channel.invokeMethod('playRingtone', {'uri': uri});
    } catch (e) {
      // Si falla el canal nativo, usar audioplayers con el URI
      try {
        await _player.play(UrlSource(uri));
      } catch (_) {}
    }
  }

  static Future<void> stop() async {
    _isPlaying = false;
    try {
      await _channel.invokeMethod('stopRingtone');
    } catch (_) {}
    await _player.stop();
  }

  static Future<void> preview(String soundId) async {
    await stop();
    try {
      if (soundId.startsWith('/') || soundId.startsWith('file://')) {
        final path = soundId.replaceFirst('file://', '');
        await _player.play(DeviceFileSource(path));
      } else {
        await _playSystemSound(soundId);
      }
      // Detener preview después de 3 segundos
      Future.delayed(const Duration(seconds: 3), stop);
    } catch (_) {}
  }

  static bool get isPlaying => _isPlaying;
}
