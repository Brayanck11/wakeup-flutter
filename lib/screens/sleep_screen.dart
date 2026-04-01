import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('CICLO DE SUEÑO'), backgroundColor: AppTheme.s1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card('🌙 Meta de sueño', '8 horas por noche', AppTheme.purple),
          const SizedBox(height: 12),
          _card('🎵 Sonidos para dormir', 'Lluvia, Océano, Bosque, Chimenea...', AppTheme.blue),
          const SizedBox(height: 12),
          _card('⏱ Temporizador', 'Apagar sonido automáticamente', AppTheme.orange),
          const SizedBox(height: 12),
          _card('📓 Diario de sueño', 'Registra cómo dormiste', AppTheme.green),
        ],
      ),
    );
  }

  Widget _card(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.s1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(child: Text(title.substring(0, 2), style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.substring(3), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textColor)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.muted),
        ],
      ),
    );
  }
}
