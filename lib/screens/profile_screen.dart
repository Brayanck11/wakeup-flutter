import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Usuario';
  String _emoji = '😴';
  int _dismiss = 0;
  int _snooze = 0;
  int _streak = 0;

  final _emojis = ['😴','🦁','🦅','🐺','🔥','⚡','🏆','💪','🎯','🚀','🧠','⭐'];
  final _nameCtrl = TextEditingController();

  static const _achievements = [
    {'id':'a1','icon':'⏰','name':'Primer Despertar','desc':'Resuelve tu primera alarma','tgt':1,'key':'dismiss'},
    {'id':'a2','icon':'🎯','name':'Sin Excusas','desc':'5 alarmas sin snooze','tgt':5,'key':'streak'},
    {'id':'a3','icon':'🔟','name':'Disciplinado','desc':'Resuelve 10 alarmas','tgt':10,'key':'dismiss'},
    {'id':'a4','icon':'🏆','name':'Maestro','desc':'Resuelve 50 alarmas','tgt':50,'key':'dismiss'},
    {'id':'a5','icon':'🔥','name':'Racha de Fuego','desc':'7 alarmas sin snooze','tgt':7,'key':'streak'},
    {'id':'a6','icon':'💪','name':'Constante','desc':'25 alarmas resueltas','tgt':25,'key':'dismiss'},
    {'id':'a7','icon':'🧮','name':'Matemático','desc':'10 retos de mates','tgt':10,'key':'math'},
    {'id':'a8','icon':'🔬','name':'Curioso','desc':'10 preguntas de cultura','tgt':10,'key':'cultura'},
    {'id':'a9','icon':'🧩','name':'Sudoku Pro','desc':'5 sudokus completados','tgt':5,'key':'sudoku'},
    {'id':'a10','icon':'🌟','name':'Leyenda','desc':'Resuelve 100 alarmas','tgt':100,'key':'dismiss'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final stats = await StorageService.loadStats();
    final history = await StorageService.loadHistory();

    // Calcular racha
    int streak = 0;
    for (final h in history) {
      if ((h['snoozes'] ?? 0) == 0) streak++;
      else break;
    }

    setState(() {
      _name = p.getString('prof_name') ?? 'Usuario';
      _emoji = p.getString('prof_emoji') ?? '😴';
      _nameCtrl.text = _name;
      _dismiss = stats['dismiss'] ?? 0;
      _snooze = stats['snooze'] ?? 0;
      _streak = streak;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('prof_name', _name);
    await p.setString('prof_emoji', _emoji);
  }

  Map<String, int> get _progress => {
    'dismiss': _dismiss,
    'streak': _streak,
    'math': 0,
    'cultura': 0,
    'sudoku': 0,
  };

  int _achProgress(Map a) {
    final key = a['key'] as String;
    final tgt = a['tgt'] as int;
    return (_progress[key] ?? 0).clamp(0, tgt);
  }

  bool _achUnlocked(Map a) => _achProgress(a) >= (a['tgt'] as int);

  String get _levelLabel {
    if (_dismiss >= 100) return 'NIVEL 5 · LEYENDA';
    if (_dismiss >= 50) return 'NIVEL 4 · EXPERTO';
    if (_dismiss >= 25) return 'NIVEL 3 · CONSTANTE';
    if (_dismiss >= 10) return 'NIVEL 2 · APRENDIZ';
    return 'NIVEL 1 · DORMILÓN';
  }

  double get _levelProgress {
    if (_dismiss >= 100) return 1.0;
    if (_dismiss >= 50) return (_dismiss - 50) / 50;
    if (_dismiss >= 25) return (_dismiss - 25) / 25;
    if (_dismiss >= 10) return (_dismiss - 10) / 15;
    return _dismiss / 10;
  }

  void _pickEmoji() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Elige tu avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textColor)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _emojis.map((e) => GestureDetector(
              onTap: () {
                setState(() => _emoji = e);
                _save();
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _emoji == e ? AppTheme.red.withOpacity(0.15) : AppTheme.s2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _emoji == e ? AppTheme.red : Colors.white.withOpacity(0.06)),
                ),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 28))),
              ),
            )).toList(),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _achievements.where((a) => _achUnlocked(a)).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('PERFIL'), backgroundColor: AppTheme.s1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TARJETA DE PERFIL
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.s1, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(children: [
              // Avatar
              GestureDetector(
                onTap: _pickEmoji,
                child: Stack(alignment: Alignment.bottomRight, children: [
                  Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      color: AppTheme.s2, shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.red.withOpacity(0.3), width: 3),
                    ),
                    child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 38))),
                  ),
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: AppTheme.red, shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.bg, width: 2)),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // Nombre editable
              GestureDetector(
                onTap: () => _showEditName(),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textColor)),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, color: AppTheme.muted, size: 14),
                ]),
              ),
              const SizedBox(height: 4),
              Text(_levelLabel, style: const TextStyle(fontSize: 10, color: AppTheme.muted, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              // Barra de nivel
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _levelProgress,
                  backgroundColor: AppTheme.s3,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.red),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 16),
              // Stats mini
              Row(children: [
                _statMini('✅', '$_dismiss', 'Resueltas', AppTheme.green),
                _statMini('😴', '$_snooze', 'Snoozes', AppTheme.orange),
                _statMini('🏅', '$unlockedCount', 'Logros', AppTheme.yellow),
                _statMini('🔥', '$_streak', 'Racha', AppTheme.red),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // LOGROS
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('LOGROS', style: TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 3, fontWeight: FontWeight.w600)),
          ),
          GridView.count(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: _achievements.map((a) {
              final unlocked = _achUnlocked(a);
              final prog = _achProgress(a);
              final tgt = a['tgt'] as int;
              final pct = prog / tgt;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.s1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: unlocked ? AppTheme.yellow.withOpacity(0.4) : Colors.white.withOpacity(0.06)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Text(a['icon'] as String,
                        style: TextStyle(fontSize: 24, color: unlocked ? null : null)),
                    if (unlocked) ...[
                      const Spacer(),
                      const Icon(Icons.check_circle, color: AppTheme.yellow, size: 14),
                    ],
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['name'] as String,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: unlocked ? AppTheme.yellow : AppTheme.textColor)),
                    const SizedBox(height: 2),
                    Text(a['desc'] as String,
                        style: const TextStyle(fontSize: 9, color: AppTheme.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct, backgroundColor: AppTheme.s3,
                        valueColor: AlwaysStoppedAnimation(unlocked ? AppTheme.yellow : AppTheme.muted),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$prog/$tgt', style: const TextStyle(fontSize: 8, color: AppTheme.muted)),
                  ]),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _statMini(String icon, String value, String label, Color color) => Expanded(
    child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.muted)),
    ]),
  );

  void _showEditName() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.s1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Tu nombre', style: TextStyle(color: AppTheme.textColor)),
        content: TextField(
          controller: _nameCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textColor),
          decoration: InputDecoration(
            hintText: 'Escribe tu nombre...',
            hintStyle: const TextStyle(color: AppTheme.muted),
            filled: true, fillColor: AppTheme.s2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.muted))),
          TextButton(
            onPressed: () {
              setState(() => _name = _nameCtrl.text.trim().isEmpty ? 'Usuario' : _nameCtrl.text.trim());
              _save();
              Navigator.pop(context);
            },
            child: const Text('Guardar', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}
