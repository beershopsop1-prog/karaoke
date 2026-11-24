import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/lyric_line.dart';
import '../models/song.dart';
import '../services/app_state.dart';
import '../services/lrc_parser.dart';
import '../widgets/lyrics_view.dart';

/// Экран караоке. Играет минусовку (если есть) или оригинал, показывает текст
/// в такт. Фон — плавно переливающийся градиент (без видео, чтобы приложение
/// надёжно собиралось под Windows одним файлом).
class PlayerScreen extends StatefulWidget {
  final Song song;
  final AppState appState;
  const PlayerScreen({super.key, required this.song, required this.appState});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  late final AnimationController _bg;

  late Song _song;
  List<LyricLine> _lines = [];
  int _currentIndex = -1;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _isPlaying = false;

  StreamSubscription? _posSub, _durSub, _stateSub, _completeSub;

  @override
  void initState() {
    super.initState();
    _bg = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _song = widget.song;
    _start(_song);
  }

  Future<void> _start(Song song) async {
    setState(() {
      _song = song;
      _lines = [];
      _currentIndex = -1;
      _position = Duration.zero;
    });
    await _loadLyrics(song);
    await _prepare(song);
  }

  Future<void> _loadLyrics(Song song) async {
    if (song.lrcPath == null) return;
    try {
      final content = await File(song.lrcPath!).readAsString();
      setState(() => _lines = LrcParser.parse(content));
    } catch (_) {}
  }

  Future<void> _prepare(Song song) async {
    await _player.stop();
    await _player.setSource(DeviceFileSource(song.playablePath));
    _posSub ??= _player.onPositionChanged.listen((p) {
      setState(() {
        _position = p;
        _currentIndex = LrcParser.currentLineIndex(_lines, p);
      });
    });
    _durSub ??= _player.onDurationChanged.listen((d) {
      setState(() => _total = d);
    });
    _stateSub ??= _player.onPlayerStateChanged.listen((s) {
      setState(() => _isPlaying = s == PlayerState.playing);
    });
    _completeSub ??= _player.onPlayerComplete.listen((_) => _onComplete());
    await _player.resume();
  }

  void _onComplete() {
    final next = widget.appState.popNextInQueue();
    if (next != null) {
      _start(next);
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    _bg.dispose();
    super.dispose();
  }

  void _toggle() => _isPlaying ? _player.pause() : _player.resume();
  void _seek(int s) => _player.seek(_position + Duration(seconds: s));

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bg,
        builder: (context, child) {
          final t = _bg.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF1A1033), const Color(0xFF0D2340), t)!,
                  Color.lerp(const Color(0xFF3A1052), const Color(0xFF102840), t)!,
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: LyricsView(lines: _lines, currentIndex: _currentIndex),
              ),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(_song.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  Text(_song.artist,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            Tooltip(
              message: _song.hasInstrumental
                  ? 'Минусовка (без вокала)'
                  : 'Оригинал (вокал не вырезан)',
              child: Icon(
                _song.hasInstrumental ? Icons.mic_off : Icons.music_note,
                color: _song.hasInstrumental
                    ? Colors.greenAccent
                    : Colors.white54,
              ),
            ),
          ],
        ),
      );

  Widget _controls() {
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : _position.inMilliseconds / _total.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(_fmt(_position),
                  style: const TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  activeColor: Colors.amberAccent,
                  inactiveColor: Colors.white24,
                  onChanged: (v) => _player.seek(_total * v),
                ),
              ),
              Text(_fmt(_total),
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  onPressed: () => _seek(-10)),
              const SizedBox(width: 20),
              IconButton(
                  iconSize: 64,
                  icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.amberAccent),
                  onPressed: _toggle),
              const SizedBox(width: 20),
              IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.forward_10, color: Colors.white),
                  onPressed: () => _seek(10)),
              const SizedBox(width: 20),
              IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: _onComplete),
            ],
          ),
        ],
      ),
    );
  }
}
