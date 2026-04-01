import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/alarm.dart';
import '../services/storage_service.dart';
import '../services/alarm_scheduler.dart';
import '../services/audio_service.dart';
import 'sound_picker_screen.dart';

class AddAlarmScreen extends StatefulWidget {
  const AddAlarmScreen({super.key});

  @override
  State<AddAlarmScreen> createState() => _AddAlarmScreenState();
}

class _AddAlarmScreenState extends State<AddAlarmScreen> {
  int _hour = 7, _minute = 0;
  String _label = '';
  String _challenge = 'math';
  String _difficulty = 'easy';
  String _sound = 'beep';
  String _color = '#FF2D55';
  List<int> _days = [];
  bool _gradual = false;

  final _labelController = TextEditingController();

  final _challenges = [
    {'v': 'math', 'l': '🧮 Matemáticas'},
    {'v': 'incognita', 'l': '🧮 Ecuación X'},
    {'v': 'sequence', 'l': '🔢 Secuencia'},
    {'v': 'shake', 'l': '📳 Agitar botón'},
    {'v': 'typing', 'l': '⌨️ Escribir frase'},
    {'v': 'pattern', 'l': '🟦 Patrón visual'},
    {'v': 'sudoku', 'l': '🧩 Sudoku'},
    {'v': 'anagram', 'l': '🔤 Anagrama'},
    {'v': 'cultura', 'l': '🔬 Cultura general'},
    {'v': 'trivia', 'l': '🧠 Trivia con IA'},
    {'v': 'random', 'l': '🎲 Aleatorio'},
  ];

  final _sounds = [
    {'v': 'beep', 'l': '📡 Beep', 'i': Icons.radio},
    {'v': 'bell', 'l': '🔔 Campana', 'i': Icons.notifications},
    {'v': 'siren', 'l': '🚨 Sirena', 'i': Icons.warning},
    {'v': 'pulse', 'l': '💓 Pulso', 'i': Icons.favorite},
    {'v': 'military', 'l': '🎺 Diana Militar', 'i': Icons.music_note},
  ];

  final _colors = [
    '#FF2D55', '#FF9500', '#30D158', '#0A84FF',
    '#BF5AF2', '#FFD60A', '#5AC8FA', '#636380',
  ];

  final _dayNames = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];

  Future<void> _save() async {
    final alarms = await StorageService.loadAlarms();
    final alarm = Alarm(
      id: DateTime.now().millisecondsSinceEpoch,
      hour: _hour,
      minute: _minute,
      label: _labelController.text.trim().isEmpty ? 'Alarma' : _labelController.text.trim(),
      challenge: _challenge,
      days: _days,
      difficulty: _difficulty,
      sound: _sound,
      color: _color,
      gradual: _gradual,
    );
    alarms.add(alarm);
    await StorageService.saveAlarms(alarms);
    // Programar en el sistema Android para que suene con pantalla apagada
    await AlarmScheduler.schedule(alarm);
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  void _setLV() {
    setState(() => _days = [0, 1, 2, 3, 4]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('NUEVA ALARMA'),
        backgroundColor: AppTheme.s1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('GUARDAR', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TIME PICKER
          _section('HORA', _buildTimePicker()),
          const SizedBox(height: 14),

          // LABEL
          _section('ETIQUETA', TextField(
            controller: _labelController,
            style: const TextStyle(color: AppTheme.textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Ej: Trabajo, Gym, Clase...',
              hintStyle: const TextStyle(color: AppTheme.muted),
              filled: true,
              fillColor: AppTheme.s2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.red),
              ),
            ),
          )),
          const SizedBox(height: 14),

          // COLOR
          _section('COLOR DE CATEGORÍA', _buildColorPicker()),
          const SizedBox(height: 14),

          // DÍAS
          _section('REPETIR DÍAS', _buildDaysPicker()),
          const SizedBox(height: 14),

          // RETO
          _section('TIPO DE RETO', _buildDropdown(
            _challenges.map((c) => DropdownMenuItem(value: c['v'], child: Text(c['l']!))).toList(),
            _challenge,
            (v) => setState(() => _challenge = v!),
          )),
          const SizedBox(height: 14),

          // DIFICULTAD
          _section('DIFICULTAD', _buildDifficulty()),
          const SizedBox(height: 14),

          // SONIDO
          _section('SONIDO DE ALARMA', _buildSounds()),
          const SizedBox(height: 14),

          // VOLUMEN GRADUAL
          _section('OPCIONES EXTRA', _buildGradualToggle()),
          const SizedBox(height: 24),

          // GUARDAR
          ElevatedButton(
            onPressed: _save,
            child: const Text('＋ GUARDAR ALARMA'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 3, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTimePicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.s1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _timeSpinner(_hour, 0, 23, (v) => setState(() => _hour = v)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppTheme.muted)),
          ),
          _timeSpinner(_minute, 0, 59, (v) => setState(() => _minute = v)),
        ],
      ),
    );
  }

  Widget _timeSpinner(int value, int min, int max, Function(int) onChanged) {
    return Column(
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onChanged(value >= max ? min : value + 1);
          },
          icon: const Icon(Icons.keyboard_arrow_up, color: AppTheme.muted, size: 28),
        ),
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.s2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppTheme.textColor, height: 1.1),
          ),
        ),
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onChanged(value <= min ? max : value - 1);
          },
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.muted, size: 28),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 8,
      children: _colors.map((c) {
        final col = Color(int.parse(c.replaceFirst('#', 'FF'), radix: 16));
        final selected = c == _color;
        return GestureDetector(
          onTap: () { setState(() => _color = c); HapticFeedback.selectionClick(); },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: col,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2.5),
            ),
            child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysPicker() {
    return Column(
      children: [
        Row(
          children: List.generate(7, (i) {
            final selected = _days.contains(i);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (selected) _days.remove(i);
                    else _days.add(i);
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.red : AppTheme.s2,
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? AppTheme.red : Colors.white.withOpacity(0.06)),
                  ),
                  child: Center(
                    child: Text(_dayNames[i],
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppTheme.muted)),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _setLV,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
            ),
            child: const Text('🔁 Lunes a Viernes automático',
                style: TextStyle(fontSize: 11, color: AppTheme.blue)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(List<DropdownMenuItem<String>> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.s2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        dropdownColor: AppTheme.s2,
        style: const TextStyle(color: AppTheme.textColor, fontSize: 14),
        underline: const SizedBox(),
        icon: const Icon(Icons.expand_more, color: AppTheme.muted),
      ),
    );
  }

  Widget _buildDifficulty() {
    final difs = [
      {'v': 'easy', 'l': 'Fácil', 'c': AppTheme.green},
      {'v': 'medium', 'l': 'Medio', 'c': AppTheme.orange},
      {'v': 'hard', 'l': 'Difícil', 'c': AppTheme.red},
    ];
    return Row(
      children: difs.map((d) {
        final selected = d['v'] == _difficulty;
        final col = d['c'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () { setState(() => _difficulty = d['v'] as String); HapticFeedback.selectionClick(); },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? col.withOpacity(0.15) : AppTheme.s2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? col : Colors.white.withOpacity(0.06)),
              ),
              child: Text(d['l'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected ? col : AppTheme.muted, letterSpacing: 0.5)),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _soundLabel() {
    if (_sound.startsWith('/') || _sound.startsWith('file://')) {
      final parts = _sound.split('/');
      return '🎵 ${parts.last}';
    }
    if (_sound == 'default_alarm') return '⚙️ Tono de alarma del sistema';
    if (_sound == 'default_ringtone') return '📱 Tono de llamada del sistema';
    // Buscar en la lista de tonos del sistema
    return '📱 Tono seleccionado';
  }

  Widget _buildSounds() {
    return Column(
      children: [
        // Botón para abrir el selector de tonos
        GestureDetector(
          onTap: () async {
            final result = await Navigator.of(context).push<String>(
              MaterialPageRoute(builder: (_) => SoundPickerScreen(currentSound: _sound)),
            );
            if (result != null) setState(() => _sound = result);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.s2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.music_note, color: AppTheme.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_soundLabel(),
                          style: const TextStyle(fontSize: 14, color: AppTheme.textColor, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      const Text('Toca para cambiar',
                          style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Preview del tono actual
        GestureDetector(
          onTap: () => AudioService.preview(_sound),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.s2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, color: AppTheme.muted, size: 18),
                SizedBox(width: 6),
                Text('Previsualizar tono actual',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradualToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.s2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const Text('🌅', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Volumen gradual', style: TextStyle(color: AppTheme.textColor, fontSize: 13)),
                Text('El sonido sube poco a poco', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: _gradual,
            onChanged: (v) => setState(() => _gradual = v),
            activeColor: AppTheme.red,
          ),
        ],
      ),
    );
  }
}
