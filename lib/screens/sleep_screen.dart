import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});
  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  int _sleepGoal = 8;
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  bool _smartAlarm = false;
  String? _activeSound;
  double _volume = 0.5;
  int? _timerMin;
  List<Map<String, dynamic>> _diary = [];
  List<Map<String, dynamic>> _history = [];

  final _sounds = [
    {'id': 'rain', 'icon': '🌧', 'name': 'Lluvia'},
    {'id': 'ocean', 'icon': '🌊', 'name': 'Océano'},
    {'id': 'forest', 'icon': '🌲', 'name': 'Bosque'},
    {'id': 'white', 'icon': '🌫', 'name': 'Ruido blanco'},
    {'id': 'fire', 'icon': '🔥', 'name': 'Chimenea'},
    {'id': 'wind', 'icon': '💨', 'name': 'Viento'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _sleepGoal = p.getInt('sleep_goal') ?? 8;
      _smartAlarm = p.getBool('smart_alarm') ?? false;
      _wakeTime = TimeOfDay(hour: p.getInt('wake_h') ?? 7, minute: p.getInt('wake_m') ?? 0);
    });
    _loadDiary(p);
    _loadHistory(p);
  }

  void _loadDiary(SharedPreferences p) {
    final list = p.getStringList('sleep_diary') ?? [];
    setState(() {
      _diary = list.map((s) {
        final parts = s.split('||');
        return {
          'date': parts.isNotEmpty ? parts[0] : '',
          'mood': parts.length > 1 ? int.tryParse(parts[1]) ?? 3 : 3,
          'text': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
    });
  }

  void _loadHistory(SharedPreferences p) {
    final list = p.getStringList('sleep_history') ?? [];
    setState(() {
      _history = list.map((s) {
        final parts = s.split('||');
        return {
          'date': parts.isNotEmpty ? parts[0] : '',
          'hours': parts.length > 1 ? double.tryParse(parts[1]) ?? 0.0 : 0.0,
          'mood': parts.length > 2 ? int.tryParse(parts[2]) ?? 3 : 3,
        };
      }).toList();
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('sleep_goal', _sleepGoal);
    await p.setBool('smart_alarm', _smartAlarm);
    await p.setInt('wake_h', _wakeTime.hour);
    await p.setInt('wake_m', _wakeTime.minute);
  }

  TimeOfDay get _bedTime {
    final m = (((_wakeTime.hour * 60 + _wakeTime.minute) - _sleepGoal * 60) % 1440 + 1440) % 1440;
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickWake() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.red, surface: AppTheme.s2),
        ),
        child: child!,
      ),
    );
    if (picked != null) { setState(() => _wakeTime = picked); _save(); }
  }

  void _openDiary() {
    int mood = 3;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📓 Diario de sueño',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textColor)),
          const SizedBox(height: 4),
          const Text('¿Cómo dormiste esta noche?', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final m in [{'v': 5, 'e': '😄'}, {'v': 4, 'e': '🙂'}, {'v': 3, 'e': '😐'}, {'v': 2, 'e': '😕'}, {'v': 1, 'e': '😫'}])
                GestureDetector(
                  onTap: () { setSt(() => mood = m['v'] as int); HapticFeedback.selectionClick(); },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: mood == m['v'] ? AppTheme.yellow.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: mood == m['v'] ? AppTheme.yellow : Colors.transparent),
                    ),
                    child: Text(m['e'] as String, style: const TextStyle(fontSize: 32)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl, maxLines: 3,
            style: const TextStyle(color: AppTheme.textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: '¿Cómo te sientes? ¿Soñaste algo?...', hintStyle: const TextStyle(color: AppTheme.muted),
              filled: true, fillColor: AppTheme.s2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              final entry = '${DateTime.now().toIso8601String()}||$mood||${ctrl.text.trim()}';
              final diaryList = p.getStringList('sleep_diary') ?? [];
              diaryList.insert(0, entry);
              if (diaryList.length > 30) diaryList.removeLast();
              await p.setStringList('sleep_diary', diaryList);
              final histEntry = '${DateTime.now().toIso8601String()}||${_sleepGoal.toDouble()}||$mood';
              final histList = p.getStringList('sleep_history') ?? [];
              histList.insert(0, histEntry);
              if (histList.length > 30) histList.removeLast();
              await p.setStringList('sleep_history', histList);
              Navigator.pop(context);
              _load();
            },
            child: const Text('✓ GUARDAR ENTRADA'),
          ),
        ]),
      )),
    );
  }

  void _openRoutine() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _RoutineSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('CICLO DE SUEÑO'), backgroundColor: AppTheme.s1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // META DE SUEÑO
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('🌙 META DE SUEÑO'),
            const SizedBox(height: 14),
            Center(child: SizedBox(width: 130, height: 130,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: _sleepGoal / 10, strokeWidth: 9,
                  backgroundColor: AppTheme.s3,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.purple),
                  strokeCap: StrokeCap.round,
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${_sleepGoal}h', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textColor)),
                  const Text('META', style: TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 2)),
                ]),
              ]),
            )),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _infoBox('Acostarse', _fmt(_bedTime), AppTheme.purple)),
              const SizedBox(width: 8),
              Expanded(child: _infoBox('Levantarse', _fmt(_wakeTime), AppTheme.blue)),
            ]),
            const SizedBox(height: 12),
            _lbl('Horas de sueño'),
            const SizedBox(height: 6),
            Row(children: [6, 7, 8, 9].map((h) {
              final sel = h == _sleepGoal;
              return Expanded(child: GestureDetector(
                onTap: () { setState(() => _sleepGoal = h); _save(); HapticFeedback.selectionClick(); },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.purple.withOpacity(0.15) : AppTheme.s2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? AppTheme.purple : Colors.white.withOpacity(0.06)),
                  ),
                  child: Text('${h}h', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sel ? AppTheme.purple : AppTheme.muted)),
                ),
              ));
            }).toList()),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickWake,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.s2, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.alarm, color: AppTheme.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Hora de despertar', style: TextStyle(fontSize: 13, color: AppTheme.textColor)),
                    Text(_fmt(_wakeTime), style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                  ])),
                  const Icon(Icons.chevron_right, color: AppTheme.muted),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(color: AppTheme.s2, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Row(children: [
                const Text('🧠', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Alarma inteligente ±15 min', style: TextStyle(fontSize: 13, color: AppTheme.textColor)),
                  Text('Te despierta en sueño ligero', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                ])),
                Switch(value: _smartAlarm, onChanged: (v) { setState(() => _smartAlarm = v); _save(); }, activeColor: AppTheme.blue),
              ]),
            ),
          ])),
          const SizedBox(height: 12),

          // SONIDOS
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('🎵 SONIDOS PARA DORMIR'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.3,
              children: _sounds.map((s) {
                final on = _activeSound == s['id'];
                return GestureDetector(
                  onTap: () { HapticFeedback.mediumImpact(); setState(() => _activeSound = on ? null : s['id'] as String); },
                  child: Container(
                    decoration: BoxDecoration(
                      color: on ? AppTheme.purple.withOpacity(0.15) : AppTheme.s2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: on ? AppTheme.purple : Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(s['icon'] as String, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(s['name'] as String,
                          style: TextStyle(fontSize: 10, color: on ? AppTheme.purple : AppTheme.muted, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            if (_activeSound != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Text('🔊', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(child: Slider(value: _volume, onChanged: (v) => setState(() => _volume = v),
                    activeColor: AppTheme.purple, inactiveColor: AppTheme.s3)),
                Text('${(_volume * 100).round()}%', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              ]),
              const SizedBox(height: 6),
              _lbl('Apagar sonido en'),
              const SizedBox(height: 6),
              Row(children: [null, 15, 30, 45, 60].map((m) {
                final sel = m == _timerMin;
                return Expanded(child: GestureDetector(
                  onTap: () { setState(() => _timerMin = m); HapticFeedback.selectionClick(); },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.purple.withOpacity(0.15) : AppTheme.s2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? AppTheme.purple : Colors.white.withOpacity(0.06)),
                    ),
                    child: Text(m == null ? 'Off' : '${m}m', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: sel ? AppTheme.purple : AppTheme.muted, fontWeight: FontWeight.w600)),
                  ),
                ));
              }).toList()),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() { _activeSound = null; _timerMin = null; }),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.purple.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
                  child: const Text('⏹ Detener sonido', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.purple, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ])),
          const SizedBox(height: 12),

          // BOTONES ACCIÓN
          Row(children: [
            Expanded(child: _actionBtn('📓', 'Diario\nde sueño', AppTheme.green, _openDiary)),
            const SizedBox(width: 10),
            Expanded(child: _actionBtn('💊', 'Rutina\nmatutina', AppTheme.orange, _openRoutine)),
          ]),
          const SizedBox(height: 12),

          // HISTORIAL
          if (_history.isNotEmpty)
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('📈 HISTORIAL DE SUEÑO'),
              const SizedBox(height: 12),
              ..._history.take(7).map((h) {
                final hours = h['hours'] as double;
                final mood = (h['mood'] as int).clamp(1, 5);
                final dt = DateTime.tryParse(h['date'] as String) ?? DateTime.now();
                final pct = (hours / _sleepGoal).clamp(0.0, 1.0);
                final col = pct >= 0.9 ? AppTheme.green : pct >= 0.7 ? AppTheme.orange : AppTheme.red;
                const moods = ['', '😫', '😕', '😐', '🙂', '😄'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppTheme.s2, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06))),
                  child: Row(children: [
                    Container(width: 4, height: 34, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${dt.day}/${dt.month}/${dt.year}', style: const TextStyle(fontSize: 12, color: AppTheme.textColor, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      ClipRRect(borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(value: pct, backgroundColor: AppTheme.s3, valueColor: AlwaysStoppedAnimation(col), minHeight: 4)),
                    ])),
                    const SizedBox(width: 10),
                    Text(moods[mood], style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text('${hours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: col)),
                  ]),
                );
              }),
            ])),

          if (_diary.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('📓 DIARIO RECIENTE'),
              const SizedBox(height: 10),
              ..._diary.take(3).map((d) {
                final dt = DateTime.tryParse(d['date'] as String) ?? DateTime.now();
                final mood = (d['mood'] as int).clamp(1, 5);
                const moods = ['', '😫', '😕', '😐', '🙂', '😄'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.s2, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(moods[mood], style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text('${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                    ]),
                    if ((d['text'] as String).isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(d['text'] as String, style: const TextStyle(fontSize: 13, color: AppTheme.textColor)),
                    ],
                  ]),
                );
              }),
            ])),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppTheme.s1, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: child,
  );

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 2.5, fontWeight: FontWeight.w600));

  Widget _infoBox(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: AppTheme.s2, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted, letterSpacing: 1)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
    ]),
  );

  Widget _actionBtn(String icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3))),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600, height: 1.3)),
          ]),
        ),
      );
}

// ══════════════════
// RUTINA MATUTINA
// ══════════════════
class _RoutineSheet extends StatefulWidget {
  const _RoutineSheet();
  @override
  State<_RoutineSheet> createState() => _RoutineSheetState();
}

class _RoutineSheetState extends State<_RoutineSheet> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('routine') ?? [];
    setState(() {
      _items = list.map((s) {
        final parts = s.split('||');
        return {'name': parts.isNotEmpty ? parts[0] : '', 'done': parts.length > 1 ? parts[1] == 'true' : false};
      }).toList();
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('routine', _items.map((i) => '${i['name']}||${i['done']}').toList());
  }

  void _add() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.s1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Agregar recordatorio', style: TextStyle(color: AppTheme.textColor)),
      content: TextField(controller: ctrl, autofocus: true,
        style: const TextStyle(color: AppTheme.textColor),
        decoration: InputDecoration(hintText: 'Ej: Tomar agua, Vitaminas...', hintStyle: const TextStyle(color: AppTheme.muted),
          filled: true, fillColor: AppTheme.s2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppTheme.muted))),
        TextButton(onPressed: () {
          if (ctrl.text.trim().isNotEmpty) { setState(() => _items.add({'name': ctrl.text.trim(), 'done': false})); _save(); }
          Navigator.pop(context);
        }, child: const Text('Agregar', style: TextStyle(color: AppTheme.red))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('💊 Rutina matutina', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textColor)),
          IconButton(onPressed: _add, icon: const Icon(Icons.add_circle, color: AppTheme.orange, size: 28)),
        ]),
        const SizedBox(height: 4),
        const Text('Completa tus hábitos diarios', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        const SizedBox(height: 16),
        if (_items.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20),
            child: Text('Sin items. Pulsa + para agregar.', style: TextStyle(color: AppTheme.muted, fontSize: 13))))
        else
          ..._items.asMap().entries.map((e) {
            final i = e.key; final item = e.value;
            final done = item['done'] as bool;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: done ? AppTheme.green.withOpacity(0.08) : AppTheme.s2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: done ? AppTheme.green.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: () { setState(() => _items[i]['done'] = !done); _save(); HapticFeedback.lightImpact(); },
                  child: Container(width: 26, height: 26,
                    decoration: BoxDecoration(color: done ? AppTheme.green : Colors.transparent, shape: BoxShape.circle,
                      border: Border.all(color: done ? AppTheme.green : AppTheme.muted, width: 2)),
                    child: done ? const Icon(Icons.check, color: Colors.white, size: 16) : null),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item['name'] as String,
                    style: TextStyle(fontSize: 14, color: done ? AppTheme.muted : AppTheme.textColor,
                        decoration: done ? TextDecoration.lineThrough : null))),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.muted, size: 18),
                  onPressed: () { setState(() => _items.removeAt(i)); _save(); },
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              ]),
            );
          }),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('✓ LISTO')),
      ]),
    );
  }
}
