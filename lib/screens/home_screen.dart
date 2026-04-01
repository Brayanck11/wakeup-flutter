import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../models/alarm.dart';
import '../services/storage_service.dart';
import '../services/alarm_event_service.dart';
import 'alarms_screen.dart';
import 'sleep_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'alarm_firing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription? _alarmSub;

  final List<Widget> _screens = const [
    AlarmsScreen(),
    SleepScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Escuchar alarmas disparadas por el sistema Android
    _alarmSub = AlarmEventService.alarmStream.listen(_onAlarmFired, onError: (_) {});
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
    super.dispose();
  }

  Future<void> _onAlarmFired(Map<String, dynamic> data) async {
    final label = data['label'] as String? ?? 'WAKE UP';
    final sound = data['sound'] as String? ?? 'default_alarm';
    final gradual = data['gradual'] as bool? ?? false;
    final id = data['id'] as int? ?? -1;

    // Buscar alarma en storage
    final alarms = await StorageService.loadAlarms();
    Alarm? alarm = alarms.where((a) => a.id % 100000 == id % 100000).firstOrNull;

    // Si no encontramos por ID, usar datos del evento
    alarm ??= Alarm(
      id: DateTime.now().millisecondsSinceEpoch,
      hour: DateTime.now().hour,
      minute: DateTime.now().minute,
      label: label,
      challenge: 'math',
      days: [],
      difficulty: 'easy',
      sound: sound,
      color: '#FF2D55',
      gradual: gradual,
    );

    if (!mounted) return;

    // Abrir pantalla de reto encima de todo
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => AlarmFiringScreen(
          alarm: alarm!,
          onDismiss: () => setState(() {}),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.s1,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppTheme.s1,
          selectedItemColor: AppTheme.red,
          unselectedItemColor: AppTheme.muted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.alarm), activeIcon: Icon(Icons.alarm, color: AppTheme.red), label: 'Alarmas'),
            BottomNavigationBarItem(icon: Icon(Icons.bedtime_outlined), activeIcon: Icon(Icons.bedtime, color: AppTheme.red), label: 'Sueño'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart, color: AppTheme.red), label: 'Stats'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person, color: AppTheme.red), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
