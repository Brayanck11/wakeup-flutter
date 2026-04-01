import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

class SoundPickerScreen extends StatefulWidget {
  final String currentSound;
  const SoundPickerScreen({super.key, required this.currentSound});

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen> {
  static const _channel = MethodChannel('com.wakeup.alarm/ringtone');

  String _selected = '';
  bool _loading = true;
  List<Map<String, String>> _systemTones = [];
  List<Map<String, String>> _customTones = [];
  String? _previewingUri;

  // Tonos integrados de la app
  final List<Map<String, String>> _builtinTones = [
    {'title': '🔔 Tono de alarma del sistema', 'uri': 'default_alarm', 'type': 'builtin'},
    {'title': '📱 Tono de llamada del sistema', 'uri': 'default_ringtone', 'type': 'builtin'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentSound;
    _loadSystemRingtones();
    _loadCustomTones();
  }

  Future<void> _loadSystemRingtones() async {
    try {
      final List result = await _channel.invokeMethod('getSystemRingtones');
      setState(() {
        _systemTones = result.map((e) => Map<String, String>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadCustomTones() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('custom_tones') ?? [];
    setState(() {
      _customTones = saved.map((s) {
        final parts = s.split('||');
        return {'title': parts[0], 'uri': parts.length > 1 ? parts[1] : parts[0], 'type': 'custom'};
      }).toList();
    });
  }

  Future<void> _saveCustomTones() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _customTones.map((t) => '${t['title']}||${t['uri']}').toList();
    await prefs.setStringList('custom_tones', list);
  }

  Future<void> _pickMp3() async {
    // Solicitar permiso
    PermissionStatus status;
    if (Theme.of(context).platform == TargetPlatform.android) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
    } else {
      status = PermissionStatus.granted;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path ?? '';
        final name = file.name;

        if (path.isNotEmpty) {
          setState(() {
            _customTones.add({'title': '🎵 $name', 'uri': path, 'type': 'custom'});
            _selected = path;
          });
          await _saveCustomTones();
          HapticFeedback.mediumImpact();
          _showSnack('✅ "$name" agregado');
        }
      }
    } catch (e) {
      _showSnack('❌ No se pudo abrir el selector de archivos');
    }
  }

  void _preview(String uri) async {
    if (_previewingUri == uri) {
      await AudioService.stop();
      setState(() => _previewingUri = null);
    } else {
      setState(() => _previewingUri = uri);
      await AudioService.preview(uri);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _previewingUri == uri) setState(() => _previewingUri = null);
      });
    }
  }

  void _select(String uri) {
    HapticFeedback.selectionClick();
    setState(() => _selected = uri);
  }

  void _confirm() async {
    await AudioService.stop();
    if (mounted) Navigator.pop(context, _selected);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.s2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _deleteCustom(int index) async {
    setState(() => _customTones.removeAt(index));
    await _saveCustomTones();
  }

  @override
  void dispose() {
    AudioService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ELIGE EL TONO'),
        backgroundColor: AppTheme.s1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async { await AudioService.stop(); Navigator.pop(context); },
        ),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('LISTO', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.red))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // AGREGAR MP3 PROPIO
                GestureDetector(
                  onTap: _pickMp3,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle, color: AppTheme.green, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Agregar MP3 desde el celular',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textColor)),
                              SizedBox(height: 2),
                              Text('Elige cualquier canción o audio de tu almacenamiento',
                                  style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                            ],
                          ),
                        ),
                        Icon(Icons.folder_open, color: AppTheme.green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // MIS TONOS PERSONALIZADOS
                if (_customTones.isNotEmpty) ...[
                  _sectionLabel('🎵 MIS TONOS PERSONALIZADOS'),
                  ..._customTones.asMap().entries.map((e) =>
                    _toneItem(e.value['title']!, e.value['uri']!, canDelete: true, deleteIdx: e.key)),
                  const SizedBox(height: 16),
                ],

                // TONOS INTEGRADOS
                _sectionLabel('⚙️ TONOS PREDETERMINADOS'),
                ..._builtinTones.map((t) => _toneItem(t['title']!, t['uri']!)),
                const SizedBox(height: 16),

                // TONOS DEL SISTEMA ANDROID
                if (_systemTones.isNotEmpty) ...[
                  _sectionLabel('📱 TONOS DEL SISTEMA ANDROID'),
                  ..._systemTones.map((t) => _toneItem(t['title']!, t['uri']!)),
                ] else ...[
                  _sectionLabel('📱 TONOS DEL SISTEMA ANDROID'),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.s1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: const Text(
                      'No se encontraron tonos del sistema. Puedes agregar un MP3 propio desde el botón de arriba.',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 2.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _toneItem(String title, String uri, {bool canDelete = false, int? deleteIdx}) {
    final isSelected = _selected == uri;
    final isPreviewing = _previewingUri == uri;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.red.withOpacity(0.1) : AppTheme.s1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppTheme.red.withOpacity(0.4) : Colors.white.withOpacity(0.06),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => _select(uri),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.red.withOpacity(0.2) : AppTheme.s2,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSelected ? Icons.check : Icons.music_note,
            color: isSelected ? AppTheme.red : AppTheme.muted,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? AppTheme.textColor : AppTheme.textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón preview
            GestureDetector(
              onTap: () => _preview(uri),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: isPreviewing ? AppTheme.orange.withOpacity(0.2) : AppTheme.s2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPreviewing ? Icons.stop : Icons.play_arrow,
                  color: isPreviewing ? AppTheme.orange : AppTheme.muted,
                  size: 18,
                ),
              ),
            ),
            // Botón eliminar (solo tonos personalizados)
            if (canDelete && deleteIdx != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showDeleteDialog(deleteIdx, title),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: AppTheme.s2, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, color: AppTheme.muted, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int index, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.s1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Eliminar tono', style: TextStyle(color: AppTheme.textColor)),
        content: Text('¿Eliminar "$title" de mis tonos?',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.muted))),
          TextButton(
            onPressed: () { Navigator.pop(context); _deleteCustom(index); },
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}
