import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int snooze = 0, dismiss = 0;
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await StorageService.loadStats();
    final hist = await StorageService.loadHistory();
    setState(() {
      snooze = stats['snooze'] ?? 0;
      dismiss = stats['dismiss'] ?? 0;
      history = hist;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('ESTADÍSTICAS'), backgroundColor: AppTheme.s1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            _statCard('😴', '$snooze', 'Snoozes', AppTheme.orange),
            const SizedBox(width: 10),
            _statCard('✅', '$dismiss', 'Resueltas', AppTheme.green),
          ]),
          const SizedBox(height: 16),
          const Text('HISTORIAL RECIENTE',
              style: TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 3, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Sin historial aún', style: TextStyle(color: AppTheme.muted)),
            ))
          else
            ...history.take(15).map((h) => _histItem(h)),
        ],
      ),
    );
  }

  Widget _statCard(String icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.s1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: color, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _histItem(Map<String, dynamic> h) {
    final ok = (h['snoozes'] ?? 0) == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.s1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: ok ? AppTheme.green : AppTheme.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${h['name']} — ${h['time']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textColor)),
                Text(h['ts']?.toString().substring(0, 10) ?? '',
                    style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ok ? AppTheme.green.withOpacity(0.12) : AppTheme.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(ok ? '✓ OK' : '+${h['snoozes']}',
                style: TextStyle(fontSize: 10, color: ok ? AppTheme.green : AppTheme.orange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
