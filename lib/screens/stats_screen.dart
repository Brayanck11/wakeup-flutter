import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _snooze = 0, _dismiss = 0, _streak = 0;
  String _bestChallenge = '—';
  List<Map<String, dynamic>> _history = [];
  // Datos de la semana: índice 0=Lunes, 6=Domingo
  List<int> _weekOk = List.filled(7, 0);
  List<int> _weekSn = List.filled(7, 0);

  static const _challengeLabels = {
    'math': '🧮 Matemáticas', 'incognita': '🧮 Ecuación X',
    'sequence': '🔢 Secuencia', 'shake': '📳 Agitar',
    'typing': '⌨️ Escribir', 'pattern': '🟦 Patrón',
    'sudoku': '🧩 Sudoku', 'anagram': '🔤 Anagrama',
    'cultura': '🔬 Cultura', 'trivia': '🧠 Trivia IA',
    'random': '🎲 Aleatorio',
  };

  static const _dayNames = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await StorageService.loadStats();
    final history = await StorageService.loadHistory();

    // Calcular racha
    int streak = 0;
    for (final h in history) {
      if ((h['snoozes'] ?? 0) == 0) streak++;
      else break;
    }

    // Reto más completado
    final cc = Map<String, dynamic>.from(stats['cc'] ?? {});
    String best = '—';
    int bestCount = 0;
    cc.forEach((key, val) {
      final count = (val as int?) ?? 0;
      if (count > bestCount) { bestCount = count; best = '${_challengeLabels[key] ?? key} (×$count)'; }
    });

    // Gráfica semanal
    final now = DateTime.now();
    final todayIdx = (now.weekday - 1) % 7; // 0=Lu
    final weekOk = List.filled(7, 0);
    final weekSn = List.filled(7, 0);
    for (final h in history) {
      final ts = DateTime.tryParse(h['ts'] ?? '');
      if (ts == null) continue;
      final diff = now.difference(ts).inDays;
      if (diff >= 7) continue;
      final dayIdx = (ts.weekday - 1) % 7;
      if ((h['snoozes'] ?? 0) == 0) weekOk[dayIdx]++;
      else weekSn[dayIdx]++;
    }

    if (mounted) setState(() {
      _snooze = stats['snooze'] ?? 0;
      _dismiss = stats['dismiss'] ?? 0;
      _streak = streak;
      _bestChallenge = best;
      _history = history;
      _weekOk = weekOk;
      _weekSn = weekSn;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.s1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Limpiar todo?', style: TextStyle(color: AppTheme.textColor)),
        content: const Text('Se borrará el historial y las estadísticas.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Limpiar', style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService.saveHistory([]);
      await StorageService.saveStats({'snooze': 0, 'dismiss': 0, 'cc': {}});
      _load();
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ESTADÍSTICAS'),
        backgroundColor: AppTheme.s1,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.muted),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // GRÁFICA SEMANAL
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppTheme.s1, borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ESTA SEMANA', style: TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 3, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              _buildWeekChart(),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _legend(AppTheme.green, 'Sin snooze'),
                const SizedBox(width: 16),
                _legend(AppTheme.orange, 'Con snooze'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          // STATS GRID
          GridView.count(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            children: [
              _statCard('😴', '$_snooze', 'Snoozes totales', AppTheme.orange),
              _statCard('✅', '$_dismiss', 'Alarmas resueltas', AppTheme.green),
              _statCard('⏱', _snooze > 0 && _dismiss > 0 ? (_snooze / _dismiss).toStringAsFixed(1) : '0', 'Snooze promedio', AppTheme.blue),
              _statCard('🔥', '$_streak', 'Racha sin snooze', AppTheme.red),
            ],
          ),
          const SizedBox(height: 10),

          // RETO MÁS COMPLETADO
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.s1, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: Row(children: [
              const Text('🏆', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RETO MÁS COMPLETADO',
                    style: TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_bestChallenge,
                    style: const TextStyle(fontSize: 14, color: AppTheme.purple, fontWeight: FontWeight.w700)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // HISTORIAL
          const Text('HISTORIAL RECIENTE',
              style: TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 3, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_history.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32),
              child: Text('Sin historial aún', style: TextStyle(color: AppTheme.muted, fontSize: 13))))
          else
            ..._history.take(20).map((h) => _histItem(h)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
    final maxVal = _weekOk.asMap().entries.map((e) => e.value + _weekSn[e.key]).reduce((a, b) => a > b ? a : b);
    final max = maxVal < 1 ? 1 : maxVal;
    final todayIdx = (DateTime.now().weekday - 1) % 7;

    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final ok = _weekOk[i];
          final sn = _weekSn[i];
          final tot = ok + sn;
          final okH = (ok / max * 80).clamp(0.0, 80.0);
          final snH = (sn / max * 80).clamp(0.0, 80.0);
          final isToday = i == todayIdx;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Número encima
                Text(tot > 0 ? '$tot' : '',
                    style: const TextStyle(fontSize: 9, color: AppTheme.muted)),
                const SizedBox(height: 3),
                // Barras apiladas
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (snH > 0)
                      Container(
                        height: snH,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.orange,
                          borderRadius: ok > 0
                              ? const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3))
                              : BorderRadius.circular(3),
                        ),
                      ),
                    if (okH > 0)
                      Container(
                        height: okH,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.green,
                          borderRadius: sn > 0
                              ? const BorderRadius.only(bottomLeft: Radius.circular(3), bottomRight: Radius.circular(3))
                              : BorderRadius.circular(3),
                        ),
                      ),
                    if (tot == 0)
                      Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(color: AppTheme.s3, borderRadius: BorderRadius.circular(2)),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                // Día
                Text(_dayNames[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: isToday ? AppTheme.red : AppTheme.muted,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    )),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
  ]);

  Widget _statCard(String icon, String value, String label, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.s1, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color, height: 1)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 0.5)),
    ]),
  );

  Widget _histItem(Map<String, dynamic> h) {
    final ok = (h['snoozes'] ?? 0) == 0;
    final dt = DateTime.tryParse(h['ts'] ?? '');
    final dateStr = dt != null
        ? '${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
        : '';
    final challenge = _challengeLabels[h['challenge']] ?? '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: AppTheme.s1, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: ok ? AppTheme.green : AppTheme.orange, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${h['name'] ?? '—'}  •  ${h['time'] ?? ''}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textColor)),
          const SizedBox(height: 2),
          Text('$dateStr  ·  $challenge${h['snoozes'] != null && h['snoozes'] > 0 ? '  ·  😴×${h['snoozes']}' : ''}',
              style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ok ? AppTheme.green.withOpacity(0.12) : AppTheme.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(ok ? '✓ OK' : '+${h['snoozes']}',
              style: TextStyle(fontSize: 10, color: ok ? AppTheme.green : AppTheme.orange, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
