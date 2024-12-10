import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final Playlists playlist;
  final AudioHandler audioHandler;

  const PlaylistDetailsPage({
    super.key,
    required this.playlist,
    required this.audioHandler,
  });

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  final List<Songs> _playlistSongs = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  Songs? _currentPlayingSong;

  @override
  void initState() {
    super.initState();
    _loadPlaylistSongs();
    _setupAudioHandler();
  }

  void _setupAudioHandler() {
    widget.audioHandler.playingStream.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
      }
    });

    widget.audioHandler.currentSongStream.listen((song) {
      if (mounted) {
        setState(() => _currentPlayingSong = song);
      }
    });
  }

  Future<void> _loadPlaylistSongs() async {
    try {
      setState(() => _isLoading = true);

      final request = ModelQueries.list(
        PlaylistItems.classType,
        where: PlaylistItems.PLAYLISTID.eq(widget.playlist.id),
      );
      final response = await Amplify.API.query(request: request).response;
      final playlistItems =
          response.data?.items.whereType<PlaylistItems>().toList() ?? [];

      final songs = <Songs>[];
      for (final item in playlistItems) {
        if (item.SongID == null) continue;

        final songRequest = ModelQueries.get(
          Songs.classType,
          SongsModelIdentifier(id: item.SongID!),
        );
        final songResponse =
            await Amplify.API.query(request: songRequest).response;
        if (songResponse.data != null) {
          songs.add(songResponse.data!);
        }
      }

      if (mounted) {
        setState(() {
          _playlistSongs.clear();
          _playlistSongs.addAll(songs);
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error loading playlist songs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editPlaylistName() async {
    final TextEditingController controller =
        TextEditingController(text: widget.playlist.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xffFDFDFD))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null &&
        newName.isNotEmpty &&
        newName != widget.playlist.name) {
      try {
        final updatedPlaylist = widget.playlist.copyWith(name: newName);
        final request = ModelMutations.update(updatedPlaylist);
        await Amplify.API.mutate(request: request).response;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playlist name updated')),
          );
        }
      } catch (e) {
        safePrint('Error updating playlist name: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error updating playlist name')),
          );
        }
      }
    }
  }

  Future<void> _playPlaylist() async {
    if (_playlistSongs.isEmpty) return;

    try {
      final firstSong = _playlistSongs.first;
      final url = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(
          'public/songs/${firstSong.fileType}/${firstSong.title}',
        ),
        options: const StorageGetUrlOptions(),
      ).result;

      await widget.audioHandler.playSong(firstSong, url.url.toString());
      // TODO: Queue the rest of the songs
    } catch (e) {
      safePrint('Error playing playlist: $e');
    }
  }

  Future<void> _removeSong(Songs song) async {
    try {
      final request = ModelQueries.list(
        PlaylistItems.classType,
        where: PlaylistItems.PLAYLISTID
            .eq(widget.playlist.id)
            .and(PlaylistItems.SONGID.eq(song.id)),
      );
      final response = await Amplify.API.query(request: request).response;
      final items =
          response.data?.items.whereType<PlaylistItems>().toList() ?? [];

      if (items.isNotEmpty) {
        final deleteRequest = ModelMutations.delete(items.first);
        await Amplify.API.mutate(request: deleteRequest).response;
        await _loadPlaylistSongs();
      }
    } catch (e) {
      safePrint('Error removing song: $e');
    }
  }

  Future<void> _playSong(Songs song) async {
    try {
      final title = song.title;
      if (title == null) return;

      final url = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(
          'public/songs/${song.fileType}/${song.title}',
        ),
        options: const StorageGetUrlOptions(),
      ).result;

      await widget.audioHandler.playSong(song, url.url.toString());
    } catch (e) {
      safePrint('Error playing song: $e');
    }
  }

  Widget _buildSongTile(Songs song) {
    final isCurrentSong = _currentPlayingSong?.id == song.id;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          image: DecorationImage(
            image: AssetImage('images/${song.album ?? 'logo'}.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
      title: Text(
        song.title ?? 'Unknown Title',
        style: TextStyle(
          color: isCurrentSong ? Theme.of(context).primaryColor : null,
          fontWeight: isCurrentSong ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(song.artist ?? 'Unknown Artist'),
      trailing: isCurrentSong
          ? IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: () {
                if (_isPlaying) {
                  widget.audioHandler.pause();
                } else {
                  widget.audioHandler.play();
                }
              },
            )
          : null,
      onTap: () => _playSong(song),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.playlist.name ?? 'Playlist',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editPlaylistName,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Playlist header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_playlistSongs.length} songs',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: _playlistSongs.isEmpty ? null : _playPlaylist,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play All'),
                ),
              ],
            ),
          ),
          // Songs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _playlistSongs.isEmpty
                    ? const Center(
                        child: Text(
                          'No songs in playlist',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _playlistSongs.length,
                        itemBuilder: (context, index) {
                          final song = _playlistSongs[index];
                          return Dismissible(
                            key: Key(song.id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _removeSong(song),
                            child: _buildSongTile(song),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
