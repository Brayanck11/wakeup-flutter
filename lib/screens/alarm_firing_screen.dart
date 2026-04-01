import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../theme/app_theme.dart';
import '../models/alarm.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../services/alarm_scheduler.dart';

class AlarmFiringScreen extends StatefulWidget {
  final Alarm alarm;
  final VoidCallback onDismiss;

  const AlarmFiringScreen({super.key, required this.alarm, required this.onDismiss});

  @override
  State<AlarmFiringScreen> createState() => _AlarmFiringScreenState();
}

class _AlarmFiringScreenState extends State<AlarmFiringScreen>
    with TickerProviderStateMixin {
  late AnimationController _bellController;
  late AnimationController _glowController;

  int _challengesPassed = 0;
  int _challengesTotal = 3;
  String _challengeType = 'math';
  String _difficulty = 'easy';
  int _snoozeCount = 0;

  // Challenge timer
  Timer? _timer;
  int _timerLeft = 30;
  int _timerMax = 30;

  // Math challenge
  String _equation = '';
  int _correctAnswer = 0;
  List<int> _options = [];

  // Shake challenge
  int _shakeCount = 0;
  int _shakeTarget = 20;

  // Pattern challenge
  List<Color> _patternColors = [];
  List<int> _pattern = [];
  List<int> _userPattern = [];
  bool _showingPattern = false;
  String _patternMsg = '';

  // Cultura/Trivia
  String _question = '';
  List<String> _qOptions = [];
  int _correctIdx = 0;
  bool _answered = false;

  String _feedbackText = '';
  bool _feedbackOk = false;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _difficulty = widget.alarm.difficulty;
    final snoozed = widget.alarm.snoozeCount;
    if (snoozed >= 6) _difficulty = 'hard';
    else if (snoozed >= 3 && _difficulty == 'easy') _difficulty = 'medium';

    _challengesTotal = _difficulty == 'easy' ? 2 : _difficulty == 'medium' ? 3 : 4;

    String ct = widget.alarm.challenge;
    if (ct == 'random') {
      const types = ['math', 'incognita', 'sequence', 'shake', 'typing', 'pattern', 'cultura'];
      ct = types[Random().nextInt(types.length)];
    }
    _challengeType = ct;
    _loadChallenge();
    _startBellVibration();
  }

  void _startBellVibration() {
    // Reproducir el tono de alarma configurado
    AudioService.play(widget.alarm.sound, loop: true, gradual: widget.alarm.gradual);
    // Vibración continua
    Timer.periodic(const Duration(milliseconds: 1200), (t) {
      if (!mounted) { t.cancel(); return; }
      HapticFeedback.heavyImpact();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timerMax = _difficulty == 'easy' ? 45 : _difficulty == 'medium' ? 30 : 20;
    _timerLeft = _timerMax;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { _timerLeft--; });
      if (_timerLeft <= 0) {
        t.cancel();
        _penalize();
      }
    });
  }

  void _penalize() {
    HapticFeedback.heavyImpact();
    setState(() { _feedbackText = '⏱ ¡Tiempo! Intenta de nuevo'; _feedbackOk = false; });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _loadChallenge();
    });
  }

  void _loadChallenge() {
    _timer?.cancel();
    setState(() { _feedbackText = ''; _answered = false; _shakeCount = 0; });

    switch (_challengeType) {
      case 'math': _loadMath(); break;
      case 'incognita': _loadIncognita(); break;
      case 'shake': _loadShake(); break;
      case 'pattern': _loadPattern(); break;
      case 'cultura': _loadCultura(); break;
      default: _loadMath();
    }

    if (_challengeType != 'shake') _startTimer();
  }

  void _loadMath() {
    final rng = Random();
    final ops = _difficulty == 'easy' ? ['+'] :
                _difficulty == 'medium' ? ['+', '-'] : ['+', '-', '×'];
    final op = ops[rng.nextInt(ops.length)];
    final max = _difficulty == 'easy' ? 20 : _difficulty == 'medium' ? 60 : 120;
    int a, b, ans;
    if (op == '+') { a = rng.nextInt(max) + 2; b = rng.nextInt(max) + 2; ans = a + b; }
    else if (op == '-') { a = rng.nextInt(max ~/ 2) + max ~/ 2; b = rng.nextInt(a) + 1; ans = a - b; }
    else { a = rng.nextInt(12) + 2; b = rng.nextInt(12) + 2; ans = a * b; }
    final sp = _difficulty == 'easy' ? 10 : _difficulty == 'medium' ? 25 : 60;
    final wrongs = <int>{};
    while (wrongs.length < 3) {
      final w = ans + rng.nextInt(sp * 2 + 1) - sp;
      if (w != ans && w > 0) wrongs.add(w);
    }
    final opts = [...wrongs, ans]..shuffle();
    setState(() { _equation = '$a $op $b = ?'; _correctAnswer = ans; _options = opts; });
  }

  void _loadIncognita() {
    final rng = Random();
    int x, a, b, ans;
    String eq;
    if (_difficulty == 'easy') {
      x = rng.nextInt(20) + 1; b = rng.nextInt(20) + 1; ans = x;
      eq = 'X + $b = ${x + b}';
    } else {
      a = rng.nextInt(8) + 2; x = rng.nextInt(20) + 1; b = rng.nextInt(30) + 1; ans = x;
      eq = '${a}X + $b = ${a * x + b}';
    }
    final sp = 15;
    final wrongs = <int>{};
    while (wrongs.length < 3) {
      final w = ans + rng.nextInt(sp * 2 + 1) - sp;
      if (w != ans && w > 0) wrongs.add(w);
    }
    final opts = [...wrongs, ans]..shuffle();
    setState(() { _equation = eq; _correctAnswer = ans; _options = opts; });
  }

  void _loadShake() {
    _shakeTarget = _difficulty == 'easy' ? 15 : _difficulty == 'medium' ? 25 : 40;
    setState(() { _shakeCount = 0; });
  }

  void _loadPattern() {
    final size = _difficulty == 'easy' ? 3 : _difficulty == 'medium' ? 4 : 5;
    final len = _difficulty == 'easy' ? 3 : _difficulty == 'medium' ? 5 : 7;
    final showMs = _difficulty == 'easy' ? 600 : _difficulty == 'medium' ? 480 : 350;
    final colors = [AppTheme.red, AppTheme.blue, AppTheme.green, AppTheme.orange, AppTheme.purple];
    _patternColors = colors.sublist(0, size);
    _pattern = List.generate(len, (_) => Random().nextInt(size));
    _userPattern = [];
    _showingPattern = true;
    _patternMsg = 'Observa el patrón...';
    setState(() {});
    _showPatternAnimation(showMs);
  }

  void _showPatternAnimation(int showMs) async {
    for (int i = 0; i < _pattern.length; i++) {
      if (!mounted) return;
      setState(() {});
      await Future.delayed(Duration(milliseconds: showMs));
    }
    if (mounted) {
      setState(() { _showingPattern = false; _patternMsg = '¡Repite el patrón!'; });
    }
  }

  void _loadCultura() {
    final bank = _culturaBank[_difficulty] ?? _culturaBank['easy']!;
    final q = bank[Random().nextInt(bank.length)];
    setState(() {
      _question = q['q'] as String;
      _qOptions = List<String>.from(q['opts'] as List);
      _correctIdx = q['ans'] as int;
      _answered = false;
    });
  }

  void _advance() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    _challengesPassed++;
    if (_challengesPassed >= _challengesTotal) {
      _dismiss();
    } else {
      const types = ['math', 'incognita', 'shake', 'pattern', 'cultura'];
      final idx = types.indexOf(_challengeType);
      _challengeType = types[(idx + 1) % types.length];
      setState(() {});
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _loadChallenge();
      });
    }
  }

  void _dismiss() async {
    _timer?.cancel();
    _bellController.stop();
    _glowController.stop();
    await AudioService.stop();
    await AlarmScheduler.stopAlarmService(); // Detener foreground service

    final history = await StorageService.loadHistory();
    history.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'name': widget.alarm.label,
      'time': widget.alarm.timeStr,
      'snoozes': _snoozeCount,
      'challenge': widget.alarm.challenge,
      'ts': DateTime.now().toIso8601String(),
    });
    if (history.length > 50) history.removeLast();
    await StorageService.saveHistory(history);

    final stats = await StorageService.loadStats();
    stats['dismiss'] = (stats['dismiss'] ?? 0) + 1;
    // Registrar reto completado en cc
    final cc = Map<String, dynamic>.from(stats['cc'] ?? {});
    final ct = widget.alarm.challenge == 'random' ? _challengeType : widget.alarm.challenge;
    cc[ct] = (cc[ct] ?? 0) + 1;
    stats['cc'] = cc;
    await StorageService.saveStats(stats);

    widget.onDismiss();
    if (mounted) Navigator.pop(context);
  }

  void _snooze() async {
    _timer?.cancel();
    await AudioService.stop();
    await AlarmScheduler.stopAlarmService();
    _snoozeCount++;
    widget.alarm.snoozeCount++;
    final now = DateTime.now().add(const Duration(minutes: 5));
    widget.alarm.hour = now.hour;
    widget.alarm.minute = now.minute;
    widget.alarm.fired = false;
    widget.alarm.enabled = true;

    final alarms = await StorageService.loadAlarms();
    final idx = alarms.indexWhere((a) => a.id == widget.alarm.id);
    if (idx >= 0) alarms[idx] = widget.alarm;
    await StorageService.saveAlarms(alarms);

    final stats = await StorageService.loadStats();
    stats['snooze'] = (stats['snooze'] ?? 0) + 1;
    await StorageService.saveStats(stats);

    widget.onDismiss();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    AudioService.stop();
    AlarmScheduler.stopAlarmService();
    _bellController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Glow de fondo animado
          AnimatedBuilder(
            animation: _glowController,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    AppTheme.red.withOpacity(0.12 * _glowController.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _bellController,
                        builder: (_, __) => Transform.rotate(
                          angle: (_bellController.value - 0.5) * 0.4,
                          child: const Text('⏰', style: TextStyle(fontSize: 56)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.alarm.label.toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.muted, letterSpacing: 3),
                      ),
                      Text(
                        widget.alarm.timeStr,
                        style: const TextStyle(
                          fontSize: 72, fontWeight: FontWeight.w800,
                          color: AppTheme.red, letterSpacing: -2, height: 1,
                        ),
                      ),
                      if (_snoozeCount > 0)
                        Text('😴 Snooze ×$_snoozeCount',
                            style: const TextStyle(fontSize: 11, color: AppTheme.orange)),
                    ],
                  ),
                ),

                // Progress dots
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: List.generate(_challengesTotal, (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i < _challengesPassed ? AppTheme.green :
                                 i == _challengesPassed ? AppTheme.red : AppTheme.s3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                  ),
                ),

                // Timer bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _timerMax > 0 ? _timerLeft / _timerMax : 1,
                            backgroundColor: AppTheme.s3,
                            valueColor: AlwaysStoppedAnimation(
                              _timerLeft / _timerMax < 0.35 ? AppTheme.red : AppTheme.green,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text('$_timerLeft',
                            style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Challenge box
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.s1,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.red.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _challengeLabel(),
                                style: const TextStyle(fontSize: 9, color: AppTheme.orange,
                                    letterSpacing: 3, fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _diffColor().withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _difficulty == 'easy' ? 'FÁCIL' :
                                  _difficulty == 'medium' ? 'MEDIO' : 'DIFÍCIL',
                                  style: TextStyle(fontSize: 8, color: _diffColor(),
                                      fontWeight: FontWeight.w600, letterSpacing: 1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildChallenge(),
                          if (_feedbackText.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(_feedbackText,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _feedbackOk ? AppTheme.green : AppTheme.red,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    children: [
                      Text('Reto ${_challengesPassed + 1} de $_challengesTotal',
                          style: const TextStyle(fontSize: 10, color: AppTheme.muted, letterSpacing: 2)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _snooze,
                        child: const Text('⏸ Posponer 5 min',
                            style: TextStyle(color: AppTheme.muted, fontSize: 12, letterSpacing: 1.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallenge() {
    switch (_challengeType) {
      case 'math':
      case 'incognita':
        return _buildMathChallenge();
      case 'shake':
        return _buildShakeChallenge();
      case 'pattern':
        return _buildPatternChallenge();
      case 'cultura':
        return _buildCulturaChallenge();
      default:
        return _buildMathChallenge();
    }
  }

  Widget _buildMathChallenge() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.s2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _challengeType == 'incognita' ? 'Encuentra el valor de X:' : _equation,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textColor),
          ),
        ),
        if (_challengeType == 'incognita') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_equation,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                    color: AppTheme.purple, letterSpacing: 2)),
          ),
        ],
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: _options.map((opt) => _mathButton(opt)).toList(),
        ),
      ],
    );
  }

  Widget _mathButton(int opt) {
    final label = _challengeType == 'incognita' ? 'X = $opt' : '$opt';
    return ElevatedButton(
      onPressed: () => _checkMath(opt),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.s2,
        foregroundColor: AppTheme.textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    );
  }

  void _checkMath(int val) {
    if (val == _correctAnswer) {
      setState(() { _feedbackText = '✓ ¡Correcto!'; _feedbackOk = true; });
      Future.delayed(const Duration(milliseconds: 600), () { if (mounted) _advance(); });
    } else {
      HapticFeedback.heavyImpact();
      setState(() { _feedbackText = '✗ Incorrecto, intenta de nuevo'; _feedbackOk = false; });
    }
  }

  Widget _buildShakeChallenge() {
    final pct = _shakeTarget > 0 ? _shakeCount / _shakeTarget : 0.0;
    return Column(
      children: [
        Text('Presiona el botón $_shakeTarget veces',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textColor)),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: '$_shakeCount',
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: AppTheme.red, height: 1)),
              TextSpan(text: ' / $_shakeTarget',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.muted, height: 1)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct.toDouble(),
            backgroundColor: AppTheme.s3,
            valueColor: const AlwaysStoppedAnimation(AppTheme.red),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() { _shakeCount++; });
            if (_shakeCount >= _shakeTarget) {
              setState(() { _feedbackText = '✓ ¡Excelente!'; _feedbackOk = true; });
              Future.delayed(const Duration(milliseconds: 500), () { if (mounted) _advance(); });
            }
          },
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.red, AppTheme.orange],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.red.withOpacity(0.4), blurRadius: 20)],
            ),
            child: const Center(child: Text('📳', style: TextStyle(fontSize: 36))),
          ),
        ),
      ],
    );
  }

  Widget _buildPatternChallenge() {
    final size = _patternColors.length;
    return Column(
      children: [
        Text('Observa y repite el patrón',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textColor)),
        const SizedBox(height: 8),
        Text(_patternMsg, style: const TextStyle(fontSize: 11, color: AppTheme.muted, letterSpacing: 1)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: size,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(size, (i) {
            final col = _patternColors[i];
            final isNext = !_showingPattern && _userPattern.length < _pattern.length
                && _pattern[_userPattern.length] == i;
            return GestureDetector(
              onTap: _showingPattern ? null : () => _tapPattern(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isNext ? col.withOpacity(0.3) : col.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: col.withOpacity(0.4), width: 2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _tapPattern(int idx) {
    HapticFeedback.selectionClick();
    final expected = _pattern[_userPattern.length];
    _userPattern.add(idx);
    if (idx != expected) {
      HapticFeedback.heavyImpact();
      setState(() { _feedbackText = '✗ Incorrecto'; _feedbackOk = false; });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) { _userPattern.clear(); _loadPattern(); }
      });
      return;
    }
    if (_userPattern.length == _pattern.length) {
      setState(() { _feedbackText = '✓ ¡Correcto!'; _feedbackOk = true; });
      Future.delayed(const Duration(milliseconds: 700), () { if (mounted) _advance(); });
    } else {
      setState(() {});
    }
  }

  Widget _buildCulturaChallenge() {
    final labels = ['A', 'B', 'C', 'D'];
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.s2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_question,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppTheme.textColor, height: 1.4)),
        ),
        const SizedBox(height: 12),
        ...List.generate(_qOptions.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: _answered ? null : () => _checkCultura(i),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _answered && i == _correctIdx ? AppTheme.green.withOpacity(0.15) :
                       AppTheme.s2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _answered && i == _correctIdx ? AppTheme.green :
                         Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Text('${labels[i]}.  ',
                      style: TextStyle(fontSize: 11, color: _answered && i == _correctIdx
                          ? AppTheme.green : AppTheme.muted, fontWeight: FontWeight.w700)),
                  Expanded(child: Text(_qOptions[i],
                      style: const TextStyle(fontSize: 13, color: AppTheme.textColor))),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  void _checkCultura(int idx) {
    setState(() { _answered = true; });
    if (idx == _correctIdx) {
      setState(() { _feedbackText = '✓ ¡Correcto!'; _feedbackOk = true; });
      Future.delayed(const Duration(milliseconds: 1200), () { if (mounted) _advance(); });
    } else {
      HapticFeedback.heavyImpact();
      setState(() { _feedbackText = '✗ Incorrecto'; _feedbackOk = false; });
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) { _loadCultura(); }
      });
    }
  }

  String _challengeLabel() {
    const labels = {
      'math': '🧮 MATEMÁTICAS', 'incognita': '🧮 ECUACIÓN X',
      'shake': '📳 AGITAR', 'pattern': '🟦 PATRÓN VISUAL',
      'cultura': '🔬 CULTURA GENERAL',
    };
    return labels[_challengeType] ?? 'RETO';
  }

  Color _diffColor() => _difficulty == 'easy' ? AppTheme.green :
      _difficulty == 'medium' ? AppTheme.orange : AppTheme.red;

  // Banco de preguntas de cultura general
  static const _culturaBank = {
    'easy': [
      {'q': '¿Cuántos continentes tiene la Tierra?', 'opts': ['5','6','7','8'], 'ans': 2},
      {'q': '¿Cuál es el animal terrestre más rápido?', 'opts': ['León','Guepardo','Caballo','Antílope'], 'ans': 1},
      {'q': '¿Cuántos meses tiene un año?', 'opts': ['10','11','12','13'], 'ans': 2},
      {'q': '¿Cuál es la capital de Francia?', 'opts': ['Madrid','París','Roma','Londres'], 'ans': 1},
    ],
    'medium': [
      {'q': '¿Cuál es el río más largo del mundo?', 'opts': ['Amazonas','Nilo','Yangtsé','Danubio'], 'ans': 1},
      {'q': '¿En qué año llegó el hombre a la Luna?', 'opts': ['1965','1967','1969','1972'], 'ans': 2},
      {'q': '¿Cuántos huesos tiene el cuerpo humano adulto?', 'opts': ['196','206','216','226'], 'ans': 1},
      {'q': '¿Quién pintó La Mona Lisa?', 'opts': ['Miguel Ángel','Rafael','Leonardo da Vinci','Botticelli'], 'ans': 2},
    ],
    'hard': [
      {'q': '¿En qué año fue fundada Constantinopla?', 'opts': ['230 d.C.','284 d.C.','330 d.C.','395 d.C.'], 'ans': 2},
      {'q': '¿Cuál es el símbolo químico del wolframio?', 'opts': ['Wo','Wf','W','Wm'], 'ans': 2},
      {'q': '¿Qué escritor colombiano ganó el Nobel de Literatura en 1982?', 'opts': ['Jorge Isaacs','Gabriel García Márquez','Tomás González','Álvaro Mutis'], 'ans': 1},
    ],
  };
}
