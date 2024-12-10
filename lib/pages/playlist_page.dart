import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'playlist_details_page.dart';

class PlaylistPage extends StatefulWidget {
  final AudioHandler audioHandler;

  const PlaylistPage({
    super.key,
    required this.audioHandler,
  });

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  List<Playlists?> _playlists = [];
  bool _isLoading = true;
  final _playlistNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  Future<void> _fetchPlaylists() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final request = ModelQueries.list(
        Playlists.classType,
        where: Playlists.USERID.eq(user.userId),
      );

      final response = await Amplify.API.query(request: request).response;
      final items = response.data?.items;

      if (mounted) {
        setState(() {
          _playlists = items ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error fetching playlists: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createPlaylist(String name) async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final newPlaylist = Playlists(
        name: name,
        userID: user.userId,
      );

      final request = ModelMutations.create(newPlaylist);
      await Amplify.API.mutate(request: request).response;

      _fetchPlaylists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist created successfully')),
        );
      }
    } catch (e) {
      safePrint('Error creating playlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error creating playlist')),
        );
      }
    }
  }

  Future<void> _deletePlaylist(Playlists playlist) async {
    try {
      final request = ModelMutations.delete(playlist);
      await Amplify.API.mutate(request: request).response;

      _fetchPlaylists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist deleted successfully')),
        );
      }
    } catch (e) {
      safePrint('Error deleting playlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting playlist')),
        );
      }
    }
  }

  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text('Create Playlist'),
        content: TextField(
          controller: _playlistNameController,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              _playlistNameController.clear();
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('Create'),
            onPressed: () {
              if (_playlistNameController.text.isNotEmpty) {
                _createPlaylist(_playlistNameController.text);
                _playlistNameController.clear();
                Navigator.pop(context);
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
        title: const Text('My Playlists'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreatePlaylistDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.queue_music,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No Playlists Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a playlist to organize your music',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreatePlaylistDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Playlist'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];
                    if (playlist == null) return const SizedBox.shrink();

                    return Card(
                      color: const Color(0xFF151515),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF303030),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.queue_music,
                            size: 32,
                            color: Color(0xff909090),
                          ),
                        ),
                        title: Text(
                          playlist.name ?? 'Untitled Playlist',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showPlaylistOptions(playlist),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlaylistDetailsPage(
                                playlist: playlist,
                                audioHandler: widget.audioHandler,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showPlaylistOptions(Playlists playlist) {
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
              leading: const Icon(Icons.edit),
              title: const Text('Rename Playlist'),
              onTap: () {
                Navigator.pop(context);
                // Implement rename functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xffa91d3a)),
              title: const Text('Delete Playlist',
                  style: TextStyle(
                      color: Color(0xffa91d3a), fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _deletePlaylist(playlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }
}
