import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/app_state.dart';
import 'add_song_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

/// Главный экран: библиотека + очередь.
class HomeScreen extends StatelessWidget {
  final AppState appState;
  const HomeScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF161628),
            title: const Text('Караоке'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(appState: appState)),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (appState.queue.isNotEmpty) _queueBar(context),
              Expanded(child: _library(context)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.amberAccent,
            foregroundColor: Colors.black,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddSongScreen(appState: appState)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Добавить песню'),
          ),
        );
      },
    );
  }

  Widget _queueBar(BuildContext context) => Container(
        color: const Color(0xFF1C1C30),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.queue_music, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'В очереди: ${appState.queue.length} — '
                '${appState.queue.map((s) => s.title).take(3).join(", ")}'
                '${appState.queue.length > 3 ? "…" : ""}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                final first = appState.popNextInQueue();
                if (first != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            PlayerScreen(song: first, appState: appState)),
                  );
                }
              },
              child: const Text('Играть'),
            ),
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white38, size: 20),
              onPressed: appState.clearQueue,
            ),
          ],
        ),
      );

  Widget _library(BuildContext context) {
    if (appState.library.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music, color: Colors.white24, size: 72),
            SizedBox(height: 16),
            Text('Библиотека пуста',
                style: TextStyle(color: Colors.white54, fontSize: 18)),
            SizedBox(height: 8),
            Text('Нажми «Добавить песню»',
                style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: appState.library.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Colors.white12),
      itemBuilder: (context, i) => _tile(context, appState.library[i]),
    );
  }

  Widget _tile(BuildContext context, Song song) => ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2A2A45),
          child: Icon(
            song.hasInstrumental ? Icons.mic_off : Icons.music_note,
            color: song.hasInstrumental ? Colors.greenAccent : Colors.white54,
          ),
        ),
        title: Text(song.title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          '${song.artist.isEmpty ? "—" : song.artist}'
          '${song.hasLyrics ? "  · текст ✓" : ""}'
          '${song.hasInstrumental ? "  · минус ✓" : ""}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PlayerScreen(song: song, appState: appState)),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: const Color(0xFF2A2A45),
          onSelected: (v) => _action(context, song, v),
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'queue',
                child: Text('В очередь', style: TextStyle(color: Colors.white))),
            if (!song.hasLyrics)
              const PopupMenuItem(
                  value: 'lyrics',
                  child:
                      Text('Найти текст', style: TextStyle(color: Colors.white))),
            if (!song.hasInstrumental)
              const PopupMenuItem(
                  value: 'vocals',
                  child: Text('Убрать вокал',
                      style: TextStyle(color: Colors.white))),
            const PopupMenuItem(
                value: 'delete',
                child:
                    Text('Удалить', style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      );

  Future<void> _action(
      BuildContext context, Song song, String action) async {
    final m = ScaffoldMessenger.of(context);
    switch (action) {
      case 'queue':
        appState.addToQueue(song);
        m.showSnackBar(
            SnackBar(content: Text('«${song.title}» в очереди')));
        break;
      case 'lyrics':
        try {
          final ok = await appState.processLyricsSearch(song);
          m.showSnackBar(SnackBar(
              content: Text(ok ? 'Текст найден!' : 'Текст не найден')));
        } catch (e) {
          m.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
        break;
      case 'vocals':
        if (!appState.backendStatus.online) {
          m.showSnackBar(const SnackBar(
              content: Text('Доп. модуль обработки не настроен')));
          return;
        }
        m.showSnackBar(
            const SnackBar(content: Text('Убираю вокал… пару минут')));
        try {
          await appState.processVocalRemoval(song);
          m.showSnackBar(const SnackBar(content: Text('Готово!')));
        } catch (e) {
          m.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
        break;
      case 'delete':
        await appState.removeSong(song.id);
        break;
    }
  }
}
