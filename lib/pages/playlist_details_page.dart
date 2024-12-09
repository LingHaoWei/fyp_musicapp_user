import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import '../models/ModelProvider.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final Playlists playlist;

  const PlaylistDetailsPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  List<Songs?> _playlistSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlaylistSongs();
  }

  Future<void> _fetchPlaylistSongs() async {
    try {
      // First, get all playlist items for this playlist
      final request = ModelQueries.list(
        PlaylistItems.classType,
        where: PlaylistItems.PLAYLISTID.eq(widget.playlist.id),
      );

      final response = await Amplify.API.query(request: request).response;
      final playlistItems = response.data?.items;

      if (playlistItems == null) {
        setState(() {
          _playlistSongs = [];
          _isLoading = false;
        });
        return;
      }

      // Then fetch the actual song details for each playlist item
      List<Songs?> songs = [];
      for (var item in playlistItems) {
        final songId = item?.SongID;
        if (songId != null && songId.isNotEmpty) {
          final songRequest = ModelQueries.get(
            Songs.classType,
            SongsModelIdentifier(id: songId),
          );
          final songResponse =
              await Amplify.API.query(request: songRequest).response;
          if (songResponse.data != null) {
            songs.add(songResponse.data);
          }
        }
      }

      if (mounted) {
        setState(() {
          _playlistSongs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error fetching playlist songs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeSongFromPlaylist(Songs song) async {
    try {
      // Find the PlaylistItem to delete
      final request = ModelQueries.list(
        PlaylistItems.classType,
        where: PlaylistItems.PLAYLISTID
            .eq(widget.playlist.id)
            .and(PlaylistItems.SONGID.eq(song.id)),
      );

      final response = await Amplify.API.query(request: request).response;
      final playlistItem = response.data?.items.first;

      if (playlistItem != null) {
        final deleteRequest = ModelMutations.delete(playlistItem);
        await Amplify.API.mutate(request: deleteRequest).response;

        _fetchPlaylistSongs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song removed from playlist')),
          );
        }
      }
    } catch (e) {
      safePrint('Error removing song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error removing song')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name ?? 'Playlist'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlistSongs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Songs Added',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add songs to your playlist',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _playlistSongs.length,
                  itemBuilder: (context, index) {
                    final song = _playlistSongs[index];
                    if (song == null) return const SizedBox.shrink();

                    return Card(
                      color: const Color(0xFF202020),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: AssetImage(
                                  'images/${song.album ?? 'logo'}.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(
                          song.title ?? 'Unknown Title',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          song.artist ?? 'Unknown Artist',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showSongOptions(song),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showSongOptions(Songs song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF202020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('Remove from Playlist',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeSongFromPlaylist(song);
              },
            ),
          ],
        ),
      ),
    );
  }
}
