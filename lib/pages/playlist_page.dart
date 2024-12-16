import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'playlist_details_page.dart';
import 'package:fyp_musicapp_aws/services/playlist_handler.dart';

class PlaylistPage extends StatefulWidget {
  final AudioHandler audioHandler;
  final PlaylistHandler playlistHandler;

  const PlaylistPage({
    super.key,
    required this.audioHandler,
    required this.playlistHandler,
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
    _setupPlaylistHandler();
    widget.playlistHandler.refreshPlaylists();
  }

  void _setupPlaylistHandler() {
    widget.playlistHandler.playlistsStream.listen((playlists) {
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _isLoading = false;
        });
      }
    });
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

      // Refresh playlists through the handler
      await widget.playlistHandler.refreshPlaylists();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist created successfully')),
      );
    } catch (e) {
      safePrint('Error creating playlist: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error creating playlist')),
      );
    }
  }

  Future<void> _renamePlaylist(Playlists playlist) async {
    final controller = TextEditingController(text: playlist.name);
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
          newName == playlist.name ||
          !mounted) {
        controller.dispose();
        return;
      }

      final updatedPlaylist = playlist.copyWith(name: newName);
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
        const SnackBar(content: Text('Playlist renamed successfully')),
      );
    } catch (e) {
      safePrint('Error renaming playlist: $e');
      if (!mounted) {
        controller.dispose();
        return;
      }
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Error renaming playlist')),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deletePlaylist(Playlists playlist) async {
    if (!mounted) return;

    // Show confirmation dialog
    final bool confirmed = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF202020),
            title: const Text('Delete Playlist'),
            content:
                Text('Are you sure you want to delete "${playlist.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xffFDFDFD))),
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
        ) ??
        false;

    if (!confirmed || !mounted) return;

    try {
      // First, delete all playlist items
      final playlistItemsRequest = ModelQueries.list(
        PlaylistItems.classType,
        where: PlaylistItems.PLAYLISTID.eq(playlist.id),
      );
      final playlistItemsResponse =
          await Amplify.API.query(request: playlistItemsRequest).response;

      for (final item in playlistItemsResponse.data?.items ?? []) {
        if (item != null) {
          final deleteItemRequest = ModelMutations.delete<PlaylistItems>(item);
          await Amplify.API.mutate(request: deleteItemRequest).response;
        }
      }

      // Then delete the playlist
      final deleteRequest = ModelMutations.delete(playlist);
      await Amplify.API.mutate(request: deleteRequest).response;

      // Refresh playlists through the handler
      await widget.playlistHandler.refreshPlaylists();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist deleted successfully')),
      );
    } catch (e) {
      safePrint('Error deleting playlist: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting playlist')),
      );
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
                      const Icon(Icons.queue_music_rounded,
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
                            Icons.queue_music_rounded,
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
                                playlistHandler: widget.playlistHandler,
                              ),
                            ),
                          ).then((needsRefresh) {
                            if (needsRefresh == true) {
                              widget.playlistHandler.refreshPlaylists();
                            }
                          });
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
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename Playlist'),
            onTap: () {
              Navigator.pop(context);
              _renamePlaylist(playlist);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete Playlist'),
            onTap: () {
              Navigator.pop(context);
              _deletePlaylist(playlist);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }
}
