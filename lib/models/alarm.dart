import 'dart:convert';

class Alarm {
  final int id;
  int hour;
  int minute;
  String label;
  String challenge;
  List<int> days;
  String difficulty;
  String sound;
  String color;
  bool gradual;
  bool enabled;
  bool fired;
  int snoozeCount;
  bool pinned;
  int? chainId;

  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.label,
    required this.challenge,
    required this.days,
    required this.difficulty,
    required this.sound,
    required this.color,
    this.gradual = false,
    this.enabled = true,
    this.fired = false,
    this.snoozeCount = 0,
    this.pinned = false,
    this.chainId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'challenge': challenge,
        'days': days,
        'difficulty': difficulty,
        'sound': sound,
        'color': color,
        'gradual': gradual,
        'enabled': enabled,
        'fired': fired,
        'snoozeCount': snoozeCount,
        'pinned': pinned,
        'chainId': chainId,
      };

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        id: json['id'],
        hour: json['hour'],
        minute: json['minute'],
        label: json['label'],
        challenge: json['challenge'],
        days: List<int>.from(json['days'] ?? []),
        difficulty: json['difficulty'] ?? 'easy',
        sound: json['sound'] ?? 'beep',
        color: json['color'] ?? '#FF2D55',
        gradual: json['gradual'] ?? false,
        enabled: json['enabled'] ?? true,
        fired: json['fired'] ?? false,
        snoozeCount: json['snoozeCount'] ?? 0,
        pinned: json['pinned'] ?? false,
        chainId: json['chainId'],
      );

  String get timeStr =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get daysStr {
    if (days.isEmpty) return 'Una vez';
    const names = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];
    return days.map((d) => names[d]).join(' · ');
  }
}
