import 'dart:convert';
import 'package:http/http.dart' as http;

/// Поиск текста песни с таймингами — ПРЯМО из приложения, без своего сервера.
///
/// Раньше за это отвечал Python-бэкенд. Теперь приложение само обращается
/// к открытой базе LRCLIB (https://lrclib.net) по интернету. Ключ не нужен,
/// бесплатно, легально (это только текст, не музыка).
///
/// Благодаря этому поиск текста работает в одной программе — никакого
/// отдельного сервера запускать не надо.
class LyricsService {
  static const _base = 'https://lrclib.net/api';
  static const _headers = {
    'User-Agent': 'KaraokeApp/0.3 (personal karaoke app)'
  };

  /// Ищет синхронизированный текст (.lrc). Возвращает содержимое или null.
  Future<String?> search({
    required String track,
    required String artist,
  }) async {
    // 1. Пробуем точное совпадение.
    try {
      final uri = Uri.parse('$_base/get').replace(queryParameters: {
        'track_name': track,
        'artist_name': artist,
      });
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final synced = _extractSynced(resp.bodyBytes);
        if (synced != null) return synced;
      }
    } catch (_) {}

    // 2. Если точного нет — общий поиск, берём лучший результат с таймингами.
    try {
      final uri = Uri.parse('$_base/search').replace(queryParameters: {
        'track_name': track,
        'artist_name': artist,
      });
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
        for (final item in list) {
          final synced = item['syncedLyrics'];
          if (synced is String && synced.trim().isNotEmpty) {
            return synced;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  String? _extractSynced(List<int> bodyBytes) {
    final data = jsonDecode(utf8.decode(bodyBytes));
    final synced = data['syncedLyrics'];
    if (synced is String && synced.trim().isNotEmpty) return synced;
    return null;
  }
}
