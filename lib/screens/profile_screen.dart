import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('PERFIL'), backgroundColor: AppTheme.s1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.s1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.s2,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 3),
                  ),
                  child: const Center(child: Text('😴', style: TextStyle(fontSize: 36))),
                ),
                const SizedBox(height: 12),
                const Text('Usuario', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textColor)),
                const SizedBox(height: 4),
                const Text('NIVEL 1 · DORMILÓN', style: TextStyle(fontSize: 11, color: AppTheme.muted, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('LOGROS',
              style: TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 3, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            children: [
              _achievementCard('⏰', 'Primer Despertar', false),
              _achievementCard('🎯', 'Sin Excusas', false),
              _achievementCard('🔟', 'Disciplinado', false),
              _achievementCard('🏆', 'Maestro', false),
              _achievementCard('🧮', 'Genio Matemático', false),
              _achievementCard('🔥', 'Racha de Fuego', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _achievementCard(String icon, String name, bool unlocked) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.s1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked ? AppTheme.yellow.withOpacity(0.4) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(fontSize: 28, color: unlocked ? null : null),),
          const SizedBox(height: 6),
          Text(name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: unlocked ? AppTheme.yellow : AppTheme.muted,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
