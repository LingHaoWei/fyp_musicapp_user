import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:fyp_musicapp_aws/pages/audio_player_page.dart';
import 'package:fyp_musicapp_aws/services/playlist_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final Playlists playlist;
  final AudioHandler audioHandler;
  final PlaylistHandler playlistHandler;

  const PlaylistDetailsPage({
    super.key,
    required this.playlist,
    required this.audioHandler,
    required this.playlistHandler,
  });

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  final List<Songs> _playlistSongs = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  Songs? _currentPlayingSong;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

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

    widget.audioHandler.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() => _duration = duration);
      }
    });

    widget.audioHandler.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
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

  Future<void> _renamePlaylist() async {
    final controller = TextEditingController(text: widget.playlist.name);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
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
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xffa91d3a)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xffFDFDFD)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xffFDFDFD))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (newName == null ||
          newName.isEmpty ||
          newName == widget.playlist.name ||
          !mounted) {
        controller.dispose();
        return;
      }

      final updatedPlaylist = widget.playlist.copyWith(name: newName);
      final request = ModelMutations.update(updatedPlaylist);
      await Amplify.API.mutate(request: request).response;

      // Refresh playlists through the handler
      await widget.playlistHandler.refreshPlaylists();

      if (!mounted) {
        controller.dispose();
        return;
      }

      Navigator.pop(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Playlist name updated')),
      );
    } catch (e) {
      safePrint('Error updating playlist name: $e');
      if (!mounted) {
        controller.dispose();
        return;
      }
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Error updating playlist name')),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _playPlaylist() async {
    if (_playlistSongs.isEmpty) return;

    try {
      final firstSong = _playlistSongs.first;
      await widget.audioHandler.playSong(firstSong, _playlistSongs);
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
      await _storeHistory(song);
      await widget.audioHandler.playSong(song, _playlistSongs);
    } catch (e) {
      safePrint('Error playing song: $e');
    }
  }

  Future<void> _storeHistory(Songs song) async {
    try {
      // Get current user
      final user = await Amplify.Auth.getCurrentUser();
      safePrint('Current user ID: ${user.userId}');

      // Check if history entry already exists
      final existingHistoryRequest = ModelQueries.list(
        History.classType,
        where: History.USERID.eq(user.userId).and(History.SONGID.eq(song.id)),
      );
      final existingHistoryResponse =
          await Amplify.API.query(request: existingHistoryRequest).response;

      if (existingHistoryResponse.data?.items.isNotEmpty ?? false) {
        // Update existing history entry
        final existingHistory = existingHistoryResponse.data!.items.first!;
        final updateRequest = ModelMutations.update(existingHistory);
        await Amplify.API.mutate(request: updateRequest).response;
        safePrint('History entry updated for song: ${song.id}');
        return;
      }

      // Create new history entry if it doesn't exist
      final history = History(
        userID: user.userId,
        songID: song.id,
      );

      // Save to database
      final request = ModelMutations.create(history);
      await Amplify.API.mutate(request: request).response;

      safePrint('New history entry stored successfully');
    } catch (e) {
      safePrint('Error storing/updating history: $e');
    }
  }

  Future<void> _playPreviousSong() async {
    if (_playlistSongs.isEmpty || _currentPlayingSong == null) return;

    final currentIndex =
        _playlistSongs.indexWhere((s) => s.id == _currentPlayingSong?.id);
    final previousIndex =
        currentIndex <= 0 ? _playlistSongs.length - 1 : currentIndex - 1;

    if (previousIndex >= 0) {
      await _playSong(_playlistSongs[previousIndex]);
    }
  }

  Future<void> _playNextSong() async {
    if (_playlistSongs.isEmpty || _currentPlayingSong == null) return;

    final currentIndex =
        _playlistSongs.indexWhere((s) => s.id == _currentPlayingSong?.id);
    final nextIndex = (currentIndex + 1) % _playlistSongs.length;

    await _playSong(_playlistSongs[nextIndex]);
  }

  // Use these methods in your UI
  void _showAudioPlayer(Songs song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: true,
      builder: (context) => AudioPlayerPage(
        song: song,
        audioHandler: widget.audioHandler,
        isPlaying: _isPlaying,
        duration: _duration,
        position: _position,
        onPlayStateChanged: (isPlaying) =>
            setState(() => _isPlaying = isPlaying),
        onPreviousSong: _playPreviousSong,
        onNextSong: _playNextSong,
      ),
    );
  }

  void _showSongOptions(Songs song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Remove from Playlist'),
            onTap: () {
              Navigator.pop(context);
              _removeSong(song);
            },
          ),
        ],
      ),
    );
  }

  void _showPlaylistOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF202020),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename Playlist'),
            onTap: () {
              Navigator.pop(context);
              _renamePlaylist();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete Playlist'),
            onTap: () async {
              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF202020),
                  title: const Text('Delete Playlist'),
                  content: Text(
                      'Are you sure you want to delete "${widget.playlist.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xffa91d3a),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                try {
                  // Delete playlist items first
                  final itemsRequest = ModelQueries.list(
                    PlaylistItems.classType,
                    where: PlaylistItems.PLAYLISTID.eq(widget.playlist.id),
                  );
                  final itemsResponse =
                      await Amplify.API.query(request: itemsRequest).response;

                  for (final item in itemsResponse.data?.items ?? []) {
                    if (item != null) {
                      final deleteItemRequest =
                          ModelMutations.delete<PlaylistItems>(item);
                      await Amplify.API
                          .mutate(request: deleteItemRequest)
                          .response;
                    }
                  }

                  // Then delete the playlist
                  final deleteRequest = ModelMutations.delete(widget.playlist);
                  await Amplify.API.mutate(request: deleteRequest).response;

                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playlist deleted')),
                  );
                } catch (e) {
                  safePrint('Error deleting playlist: $e');
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error deleting playlist')),
                  );
                }
              }
            },
          ),
        ],
      ),
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
              icon: const Icon(Icons.more_vert),
              onPressed: _showPlaylistOptions,
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
                          final isCurrentSong =
                              _currentPlayingSong?.id == song.id;

                          return ListTile(
                            leading: FutureBuilder<String>(
                              future: widget.audioHandler
                                  .getAlbumArtUrl(song.album ?? 'logo'),
                              builder: (context, snapshot) {
                                return Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: !snapshot.hasData
                                      ? Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[800],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: snapshot.data!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              color: Colors.grey[800],
                                              child: const Center(
                                                  child:
                                                      CircularProgressIndicator()),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              color: Colors.grey[800],
                                              child:
                                                  const Icon(Icons.music_note),
                                            ),
                                          ),
                                        ),
                                );
                              },
                            ),
                            title: Text(
                              song.title ?? 'Unknown Title',
                              style: TextStyle(
                                color: isCurrentSong
                                    ? Theme.of(context).primaryColor
                                    : null,
                                fontWeight:
                                    isCurrentSong ? FontWeight.bold : null,
                              ),
                            ),
                            subtitle: Text(song.artist ?? 'Unknown Artist'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrentSong)
                                  IconButton(
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    onPressed: () {
                                      if (_isPlaying) {
                                        widget.audioHandler.pause();
                                      } else {
                                        widget.audioHandler.play();
                                      }
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _showSongOptions(song),
                                ),
                              ],
                            ),
                            onTap: () {
                              if (_currentPlayingSong?.id != song.id) {
                                _playSong(song);
                              }
                              _showAudioPlayer(song);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
