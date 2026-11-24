import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/app_state.dart';

/// Добавление песни. Текст ищется прямо из приложения (сервер не нужен).
/// "Убрать вокал" — необязательно, работает только если настроен доп. сервер.
class AddSongScreen extends StatefulWidget {
  final AppState appState;
  const AddSongScreen({super.key, required this.appState});

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  String? _audioPath;
  String? _lrcPath;
  String? _foundLyrics;
  String? _autoInstrumentalPath;
  bool _removingVocals = false;
  bool _searchingLyrics = false;

  Future<void> _pickAudio() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r?.files.single.path != null) {
      setState(() => _audioPath = r!.files.single.path);
    }
  }

  Future<void> _pickLrc() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['lrc', 'txt']);
    if (r?.files.single.path != null) {
      setState(() {
        _lrcPath = r!.files.single.path;
        _foundLyrics = null;
      });
    }
  }

  Future<void> _searchLyrics() async {
    if (_title.text.trim().isEmpty || _artist.text.trim().isEmpty) {
      _snack('Заполни название и исполнителя');
      return;
    }
    setState(() => _searchingLyrics = true);
    try {
      final lrc =
          await widget.appState.searchLyrics(_title.text.trim(), _artist.text.trim());
      if (lrc == null) {
        _snack('Текст не найден. Можно выбрать свой .lrc');
      } else {
        setState(() {
          _foundLyrics = lrc;
          _lrcPath = null;
        });
        _snack('Текст найден!');
      }
    } catch (e) {
      _snack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _searchingLyrics = false);
    }
  }

  Future<void> _removeVocals() async {
    if (_audioPath == null) {
      _snack('Сначала выбери аудиофайл');
      return;
    }
    if (!widget.appState.backendStatus.online) {
      _snack('Доп. модуль обработки не настроен (необязательно)');
      return;
    }
    setState(() => _removingVocals = true);
    try {
      final p = await widget.appState.backend.removeVocals(_audioPath!);
      setState(() => _autoInstrumentalPath = p);
      _snack('Вокал убран');
    } catch (e) {
      _snack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _removingVocals = false);
    }
  }

  Future<void> _save() async {
    if (_audioPath == null) {
      _snack('Сначала выбери аудиофайл');
      return;
    }
    String? lrc = _lrcPath;
    if (_foundLyrics != null) {
      try {
        final f = File('$_audioPath.found.lrc');
        await f.writeAsString(_foundLyrics!);
        lrc = f.path;
      } catch (_) {
        lrc = null;
      }
    }
    await widget.appState.addSong(Song(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.text.trim().isEmpty ? 'Без названия' : _title.text.trim(),
      artist: _artist.text.trim(),
      audioPath: _audioPath!,
      instrumentalPath: _autoInstrumentalPath,
      lrcPath: lrc,
    ));
    if (mounted) Navigator.pop(context);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final hasLyrics = _lrcPath != null || _foundLyrics != null;
    final vocalsAvailable = widget.appState.backendStatus.online;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Добавить песню'),
          backgroundColor: const Color(0xFF161628)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_title, 'Название песни'),
            const SizedBox(height: 12),
            _field(_artist, 'Исполнитель'),
            const SizedBox(height: 20),
            _fileBtn(
                _audioPath == null
                    ? 'Выбрать аудиофайл *'
                    : 'Аудио: ${_short(_audioPath!)}',
                Icons.audio_file,
                _pickAudio,
                _audioPath != null),
            const SizedBox(height: 10),
            _fileBtn(
                !hasLyrics
                    ? 'Свой текст .lrc (необязательно)'
                    : (_foundLyrics != null
                        ? 'Текст: найден'
                        : 'Текст: ${_short(_lrcPath!)}'),
                Icons.subtitles,
                _pickLrc,
                hasLyrics),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            _actionBtn(
              icon: Icons.search,
              label: _foundLyrics != null ? 'Текст найден ✓' : 'Найти текст',
              busy: _searchingLyrics,
              enabled: _foundLyrics == null,
              onPressed: _searchLyrics,
            ),
            const SizedBox(height: 10),
            _actionBtn(
              icon: Icons.mic_off,
              label: _autoInstrumentalPath != null
                  ? 'Вокал убран ✓'
                  : (vocalsAvailable
                      ? 'Убрать вокал'
                      : 'Убрать вокал (модуль не настроен)'),
              busy: _removingVocals,
              enabled: vocalsAvailable && _autoInstrumentalPath == null,
              onPressed: _removeVocals,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black),
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить в библиотеку',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.amberAccent)),
        ),
      );

  Widget _fileBtn(String label, IconData icon, VoidCallback onTap, bool sel) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: sel ? Colors.amberAccent : Colors.white70,
          side: BorderSide(color: sel ? Colors.amberAccent : Colors.white24),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.centerLeft,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, overflow: TextOverflow.ellipsis),
      );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required bool busy,
    required bool enabled,
    required VoidCallback onPressed,
  }) =>
      SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2A2A45),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF1C1C30),
          ),
          onPressed: (enabled && !busy) ? onPressed : null,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon),
          label: Text(busy ? 'Обработка…' : label),
        ),
      );

  String _short(String p) => p.split(RegExp(r'[\\/]')).last;
}
