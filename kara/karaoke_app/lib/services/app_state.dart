import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/backend_service.dart';
import '../services/library_storage.dart';
import '../services/lyrics_service.dart';

/// Центр состояния: библиотека, очередь, настройки.
///
/// Поиск текста теперь нативный (LyricsService) — сервер для этого НЕ нужен.
/// Сервер (backend) нужен только для необязательной функции "убрать вокал".
class AppState extends ChangeNotifier {
  final LibraryStorage _storage = LibraryStorage();
  final LyricsService _lyrics = LyricsService();

  List<Song> _library = [];
  final List<Song> _queue = [];
  String _backendUrl = 'http://localhost:8000';
  BackendStatus _backendStatus =
      const BackendStatus(online: false, demucsInstalled: false);

  List<Song> get library => List.unmodifiable(_library);
  List<Song> get queue => List.unmodifiable(_queue);
  String get backendUrl => _backendUrl;
  BackendStatus get backendStatus => _backendStatus;
  BackendService get backend => BackendService(_backendUrl);

  Future<void> init() async {
    _library = await _storage.loadLibrary();
    _backendUrl = await _storage.getBackendUrl();
    notifyListeners();
    refreshBackendStatus();
  }

  Future<void> refreshBackendStatus() async {
    _backendStatus = await backend.checkHealth();
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    _backendUrl = url.trim();
    await _storage.setBackendUrl(_backendUrl);
    notifyListeners();
    refreshBackendStatus();
  }

  // ---- Библиотека ----
  Future<void> addSong(Song song) async {
    _library.add(song);
    await _storage.saveLibrary(_library);
    notifyListeners();
  }

  Future<void> updateSong(Song song) async {
    final i = _library.indexWhere((s) => s.id == song.id);
    if (i != -1) {
      _library[i] = song;
      await _storage.saveLibrary(_library);
      notifyListeners();
    }
  }

  Future<void> removeSong(String id) async {
    _library.removeWhere((s) => s.id == id);
    _queue.removeWhere((s) => s.id == id);
    await _storage.saveLibrary(_library);
    notifyListeners();
  }

  // ---- Очередь ----
  void addToQueue(Song song) {
    _queue.add(song);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      notifyListeners();
    }
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }

  Song? popNextInQueue() {
    if (_queue.isEmpty) return null;
    final next = _queue.removeAt(0);
    notifyListeners();
    return next;
  }

  // ---- Поиск текста (нативный, без сервера) ----
  Future<bool> processLyricsSearch(Song song) async {
    final lrc = await _lyrics.search(track: song.title, artist: song.artist);
    if (lrc == null) return false;
    final file = File('${song.audioPath}.lrc');
    await file.writeAsString(lrc);
    song.lrcPath = file.path;
    await updateSong(song);
    return true;
  }

  /// Прямой поиск текста (для экрана добавления): вернёт .lrc или null.
  Future<String?> searchLyrics(String track, String artist) =>
      _lyrics.search(track: track, artist: artist);

  // ---- Убрать вокал (необязательно, нужен сервер) ----
  Future<void> processVocalRemoval(Song song) async {
    final instrumentalPath = await backend.removeVocals(song.audioPath);
    song.instrumentalPath = instrumentalPath;
    await updateSong(song);
  }
}
