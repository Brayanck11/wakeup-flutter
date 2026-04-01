import 'dart:async';
import 'package:flutter/services.dart';

class AudioService {
  static const _channel = MethodChannel('com.wakeup.alarm/ringtone');
  static bool _isPlaying = false;
  static Timer? _gradualTimer;

  /// Reproduce el tono — soporta gradual
  static Future<void> play(String soundId, {bool loop = true, bool gradual = false}) async {
    await stop();
    _isPlaying = true;

    try {
      await _channel.invokeMethod('playRingtone', {
        'uri': soundId,
        'volume': gradual ? 0.05 : 1.0,
        'loop': loop,
      });

      if (gradual) {
        double vol = 0.05;
        _gradualTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
          if (!_isPlaying) { t.cancel(); return; }
          vol = (vol + 0.1).clamp(0.0, 1.0);
          try {
            await _channel.invokeMethod('setVolume', {'volume': vol});
          } catch (_) {}
          if (vol >= 1.0) t.cancel();
        });
      }
    } catch (e) {
      // Fallback vibración si falla el audio
      HapticFeedback.heavyImpact();
    }
  }

  static Future<void> preview(String soundId) async {
    await stop();
    try {
      await _channel.invokeMethod('playRingtone', {'uri': soundId, 'volume': 0.8, 'loop': false});
      Future.delayed(const Duration(seconds: 3), stop);
    } catch (_) {}
  }

  static Future<void> stop() async {
    _isPlaying = false;
    _gradualTimer?.cancel();
    _gradualTimer = null;
    try {
      await _channel.invokeMethod('stopRingtone');
    } catch (_) {}
  }

  static bool get isPlaying => _isPlaying;
}
