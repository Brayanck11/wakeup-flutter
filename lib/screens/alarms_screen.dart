import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../models/alarm.dart';
import '../services/storage_service.dart';
import 'add_alarm_screen.dart';
import '../services/alarm_scheduler.dart';
import 'alarm_firing_screen.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});
  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  List<Alarm> _alarms = [];
  Timer? _clockTimer;
  Timer? _alarmChecker;
  String _currentTime = '';
  String _currentDate = '';
  int _totalSnooze = 0;
  int _totalDismiss = 0;
  bool _firingInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
    _loadStats();
    _startClock();
    _startChecker();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Pedir permisos críticos para Android 12+
    await AlarmScheduler.requestExactAlarm();
    await Future.delayed(const Duration(seconds: 2));
    await AlarmScheduler.requestBatteryOptimization();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _alarmChecker?.cancel();
    super.dispose();
  }

  void _startClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    const days = ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];
    const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    if (mounted) setState(() {
      _currentTime = '$h:$m:$s';
      _currentDate = '${days[now.weekday % 7]} ${now.day} ${months[now.month - 1]} ${now.year}';
    });
  }

  void _startChecker() {
    _alarmChecker = Timer.periodic(const Duration(seconds: 15), (_) => _checkAlarms());
  }

  void _checkAlarms() {
    if (_firingInProgress) return;
    final now = DateTime.now();
    for (final alarm in _alarms) {
      if (!alarm.enabled || alarm.fired) continue;
      if (alarm.hour == now.hour && alarm.minute == now.minute) {
        final dayIdx = (now.weekday - 1) % 7;
        if (alarm.days.isEmpty || alarm.days.contains(dayIdx)) {
          _fireAlarm(alarm);
          break;
        }
      }
    }
  }

  void _fireAlarm(Alarm alarm, {bool isTest = false}) async {
    if (_firingInProgress && !isTest) return;
    _firingInProgress = true;

    if (!isTest) {
      alarm.fired = true;
      if (alarm.days.isEmpty) alarm.enabled = false;
      await StorageService.saveAlarms(_alarms);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlarmFiringScreen(
          alarm: alarm,
          onDismiss: () async {
            setState(() {});
            await _loadStats();
            // ⛓ Si tiene alarma en cadena, dispararla después de 2 segundos
            if (alarm.chainId != null) {
              final chainAlarm = _alarms.where((a) => a.id == alarm.chainId).firstOrNull;
              if (chainAlarm != null && chainAlarm.enabled) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    _showChainSnack(chainAlarm.label);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) _fireAlarm(chainAlarm);
                    });
                  }
                });
              }
            }
          },
        ),
        fullscreenDialog: true,
      ),
    );
    _firingInProgress = false;
  }

  void _showChainSnack(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Text('⛓ ', style: TextStyle(fontSize: 18)),
          Text('Siguiente en cadena: $label', style: const TextStyle(color: AppTheme.textColor)),
        ]),
        backgroundColor: AppTheme.s2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.teal.withOpacity(0.4)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadAlarms() async {
    final alarms = await StorageService.loadAlarms();
    alarms.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
    });
    if (mounted) setState(() => _alarms = alarms);
  }

  Future<void> _loadStats() async {
    final stats = await StorageService.loadStats();
    if (mounted) setState(() {
      _totalSnooze = stats['snooze'] ?? 0;
      _totalDismiss = stats['dismiss'] ?? 0;
    });
  }

  Future<void> _toggleAlarm(Alarm alarm) async {
    setState(() { alarm.enabled = !alarm.enabled; alarm.fired = false; });
    await StorageService.saveAlarms(_alarms);
    if (alarm.enabled) {
      await AlarmScheduler.schedule(alarm);
    } else {
      await AlarmScheduler.cancel(alarm);
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _deleteAlarm(Alarm alarm) async {
    await AlarmScheduler.cancel(alarm);
    setState(() => _alarms.remove(alarm));
    await StorageService.saveAlarms(_alarms);
    HapticFeedback.mediumImpact();
  }

  Future<void> _pinAlarm(Alarm alarm) async {
    setState(() {
      alarm.pinned = !alarm.pinned;
      _alarms.sort((a, b) {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        return (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
      });
    });
    await StorageService.saveAlarms(_alarms);
    HapticFeedback.selectionClick();
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16)); }
    catch (_) { return AppTheme.red; }
  }

  String _nextAlarmText() {
    final active = _alarms.where((a) => a.enabled).toList();
    if (active.isEmpty) return '';
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    Alarm? best; int bestDiff = 9999;
    for (final a in active) {
      int diff = a.hour * 60 + a.minute - nowMin;
      if (diff <= 0) diff += 1440;
      if (diff < bestDiff) { bestDiff = diff; best = a; }
    }
    if (best == null) return '';
    final h = bestDiff ~/ 60;
    final m = bestDiff % 60;
    final timeStr = h > 0 ? 'en ${h}h ${m}m' : 'en ${m}m';
    return '${best.timeStr} · ${best.label} ($timeStr)';
  }

  String? _chainLabel(Alarm alarm) {
    if (alarm.chainId == null) return null;
    final chain = _alarms.where((a) => a.id == alarm.chainId).firstOrNull;
    return chain != null ? '→ ${chain.label} ${chain.timeStr}' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // RELOJ
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(children: [
                Text(_currentTime,
                    style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w800,
                        color: AppTheme.textColor, letterSpacing: -2, height: 1)),
                const SizedBox(height: 4),
                Text(_currentDate, style: const TextStyle(fontSize: 11, color: AppTheme.muted, letterSpacing: 2)),
                if (_nextAlarmText().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.red.withOpacity(0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.circle, size: 7, color: AppTheme.red),
                      const SizedBox(width: 6),
                      Text(_nextAlarmText(),
                          style: const TextStyle(fontSize: 11, color: AppTheme.red, letterSpacing: 0.5)),
                    ]),
                  ),
                ],
              ]),
            ),

            // MINI STATS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _miniStat('${_alarms.length}', 'Alarmas', AppTheme.red),
                const SizedBox(width: 8),
                _miniStat('$_totalSnooze', 'Snoozes', AppTheme.orange),
                const SizedBox(width: 8),
                _miniStat('$_totalDismiss', 'Resueltas', AppTheme.green),
              ]),
            ),
            const SizedBox(height: 14),

            // HEADER LISTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('MIS ALARMAS',
                    style: TextStyle(fontSize: 10, color: AppTheme.muted, letterSpacing: 3, fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddAlarmScreen()),
                    );
                    _loadAlarms();
                  },
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.red),
                  label: const Text('Nueva', style: TextStyle(color: AppTheme.red, fontSize: 12)),
                ),
              ]),
            ),

            // LISTA
            Expanded(
              child: _alarms.isEmpty ? _emptyState() :
              ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _alarms.length,
                itemBuilder: (_, i) => _alarmCard(_alarms[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(color: AppTheme.s1, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, height: 1)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 1)),
      ]),
    ),
  );

  Widget _alarmCard(Alarm alarm) {
    final col = _parseColor(alarm.color);
    final diffColors = {'easy': AppTheme.green, 'medium': AppTheme.orange, 'hard': AppTheme.red};
    final diffLabels = {'easy': 'Fácil', 'medium': 'Medio', 'hard': 'Difícil'};
    final challengeLabels = {
      'math':'🧮 Mates','incognita':'🧮 Ecuación X','sequence':'🔢 Secuencia',
      'shake':'📳 Agitar','typing':'⌨️ Escribir','pattern':'🟦 Patrón',
      'sudoku':'🧩 Sudoku','anagram':'🔤 Anagrama','cultura':'🔬 Cultura',
      'trivia':'🧠 Trivia IA','random':'🎲 Aleatorio',
    };
    final chain = _chainLabel(alarm);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Color.lerp(AppTheme.s1, col, 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alarm.pinned ? AppTheme.yellow.withOpacity(0.3) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Stack(children: [
        // Barra lateral
        Positioned(left: 0, top: 0, bottom: 0,
          child: Container(width: 4,
            decoration: BoxDecoration(
              color: alarm.enabled ? col : AppTheme.muted,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          child: Row(children: [
            Expanded(child: Opacity(
              opacity: alarm.enabled ? 1.0 : 0.38,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(alarm.timeStr,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                        color: alarm.enabled ? AppTheme.textColor : AppTheme.muted, height: 1, letterSpacing: -1)),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 4, children: [
                  if (alarm.pinned) _tag('📌', AppTheme.yellow),
                  _tag(alarm.label, AppTheme.muted),
                  _tag(alarm.daysStr, AppTheme.blue),
                  _tag(challengeLabels[alarm.challenge] ?? '?', AppTheme.purple),
                  _tag(diffLabels[alarm.difficulty] ?? 'Fácil', diffColors[alarm.difficulty] ?? AppTheme.green),
                  if (alarm.gradual) _tag('🌅 Gradual', AppTheme.green),
                  if (alarm.snoozeCount > 0) _tag('😴×${alarm.snoozeCount}', AppTheme.orange),
                  if (chain != null) _tag('⛓ $chain', AppTheme.teal),
                ]),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _fireAlarm(alarm, isTest: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text('▶ Probar',
                        style: TextStyle(fontSize: 10, color: AppTheme.muted, letterSpacing: 0.5)),
                  ),
                ),
              ]),
            )),
            Column(children: [
              Switch(value: alarm.enabled, onChanged: (_) => _toggleAlarm(alarm),
                  activeColor: AppTheme.red, inactiveThumbColor: AppTheme.muted, inactiveTrackColor: AppTheme.s3),
              IconButton(
                icon: Icon(alarm.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18, color: alarm.pinned ? AppTheme.yellow : AppTheme.muted),
                onPressed: () => _pinAlarm(alarm),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.muted),
                onPressed: () => _showDeleteDialog(alarm),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
    child: Text(text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.alarm_off, size: 56, color: AppTheme.muted),
    const SizedBox(height: 16),
    const Text('Sin alarmas todavía', style: TextStyle(fontSize: 14, color: AppTheme.muted, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    const Text('Pulsa + Nueva para crear una', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddAlarmScreen()));
        _loadAlarms();
      },
      icon: const Icon(Icons.add),
      label: const Text('CREAR ALARMA'),
      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
    ),
  ]));

  void _showDeleteDialog(Alarm alarm) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.s1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Eliminar alarma', style: TextStyle(color: AppTheme.textColor)),
      content: Text('¿Eliminar "${alarm.label}"?', style: const TextStyle(color: AppTheme.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.muted))),
        TextButton(onPressed: () { Navigator.pop(context); _deleteAlarm(alarm); },
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.red))),
      ],
    ),
  );
}
