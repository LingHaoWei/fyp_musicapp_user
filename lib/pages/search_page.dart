import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';
import 'dart:async';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:fyp_musicapp_aws/pages/audio_player_page.dart';
import 'package:fyp_musicapp_aws/widgets/persistent_mini_player.dart';

class SearchPage extends StatefulWidget {
  final AudioHandler audioHandler;

  const SearchPage({
    super.key,
    required this.audioHandler,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Songs> _searchResults = [];
  bool _isLoading = false;
  String _preferFileType = 'mp3';
  Timer? _debounce;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final request = ModelQueries.list(
        Users.classType,
        where: Users.NAME.eq(user.username),
      );
      final response = await Amplify.API.query(request: request).response;

      if (response.data?.items != null && response.data!.items.isNotEmpty) {
        final userProfile = response.data!.items.first;
        setState(() {
          _preferFileType = userProfile?.preferFileType ?? 'mp3';
        });
      }
    } catch (e) {
      safePrint('Error loading user preferences: $e');
    }
  }

  Future<void> _playSong(Songs song) async {
    try {
      final title = song.title;
      if (title == null) return;

      final url = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(
            'public/songs/$_preferFileType/${song.title}'),
        options: const StorageGetUrlOptions(),
      ).result;

      await widget.audioHandler.playSong(song, url.url.toString());
      await _storeHistory(song);
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

  void _showAudioPlayer(Songs song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<Duration?>(
        stream: widget.audioHandler.durationStream,
        builder: (context, durationSnapshot) {
          return StreamBuilder<Duration>(
            stream: widget.audioHandler.positionStream,
            builder: (context, positionSnapshot) {
              return AudioPlayerPage(
                song: song,
                audioHandler: widget.audioHandler,
                isPlaying: widget.audioHandler.isPlaying,
                duration: durationSnapshot.data ?? Duration.zero,
                position: positionSnapshot.data ?? Duration.zero,
                onPlayStateChanged: (_) {},
                onPreviousSong: () {},
                onNextSong: () {},
              );
            },
          );
        },
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchText = query;
      });
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    if (_searchText.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = ModelQueries.list(
        Songs.classType,
        where: Songs.FILETYPE.eq(_preferFileType),
      );
      final response = await Amplify.API.query(request: request).response;

      if (!mounted) return;

      if (response.data != null) {
        final items = response.data!.items;
        final filteredSongs = items
            .where((song) =>
                (song?.title
                        ?.toLowerCase()
                        .contains(_searchText.toLowerCase()) ??
                    false) ||
                (song?.artist
                        ?.toLowerCase()
                        .contains(_searchText.toLowerCase()) ??
                    false))
            .toList();

        setState(() {
          _searchResults.clear();
          _searchResults.addAll(filteredSongs.whereType<Songs>());
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error searching songs: $e');
      if (mounted) {
        setState(() {
          _searchResults.clear();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddToPlaylistModal(Songs song) async {
    try {
      final user = await Amplify.Auth.getCurrentUser();

      // Get user's playlists
      final playlistRequest = ModelQueries.list(
        Playlists.classType,
        where: Playlists.USERID.eq(user.userId),
      );
      final playlistResponse =
          await Amplify.API.query(request: playlistRequest).response;
      final playlists =
          playlistResponse.data?.items.whereType<Playlists>().toList() ?? [];

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF151515),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add to Playlist',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No playlists found. Create a playlist first.'),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      title: Text(playlist.name ?? 'Untitled Playlist'),
                      onTap: () async {
                        try {
                          // Check for duplicate songs
                          final existingSongsRequest = ModelQueries.list(
                            PlaylistItems.classType,
                            where: PlaylistItems.PLAYLISTID.eq(playlist.id),
                          );
                          final existingSongsResponse = await Amplify.API
                              .query(request: existingSongsRequest)
                              .response;
                          final existingSongs = existingSongsResponse
                                  .data?.items
                                  .whereType<PlaylistItems>()
                                  .toList() ??
                              [];

                          // Check if song already exists in playlist
                          final isDuplicate = existingSongs
                              .any((item) => item.SongID == song.id);

                          if (isDuplicate) {
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Song already exists in this playlist')),
                            );
                            return;
                          }

                          // Add song if not a duplicate
                          final playlistSong = PlaylistItems(
                            PlaylistID: playlist.id,
                            SongID: song.id,
                          );
                          final request = ModelMutations.create(playlistSong);
                          await Amplify.API.mutate(request: request).response;

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Added to ${playlist.name}')),
                          );
                        } catch (e) {
                          safePrint('Error adding song to playlist: $e');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Failed to add to playlist')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      safePrint('Error loading playlists: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Songs?>(
      stream: widget.audioHandler.currentSongStream,
      builder: (context, songSnapshot) {
        final currentSong = songSnapshot.data;

        return StreamBuilder<bool>(
          stream: widget.audioHandler.playingStream,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;

            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search songs...',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              body: Stack(
                children: [
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_searchResults.isEmpty && _searchText.isNotEmpty)
                    const Center(child: Text('No results found'))
                  else
                    ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final song = _searchResults[index];
                        final isCurrentSong = currentSong?.id == song.id;

                        return ListTile(
                          leading: Stack(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: AssetImage(
                                        'images/${song.album ?? 'logo'}.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
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
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: const Color(0xFF151515),
                                builder: (context) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.playlist_add),
                                      title: const Text('Add to Playlist'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showAddToPlaylistModal(song);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          onTap: () {
                            if (isCurrentSong) {
                              _showAudioPlayer(song);
                            } else {
                              _playSong(song);
                            }
                          },
                        );
                      },
                    ),
                  if (currentSong != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: PersistentMiniPlayer(
                        currentSong: currentSong,
                        isPlaying: isPlaying,
                        onTap: () => _showAudioPlayer(currentSong),
                        onPlayPause: () {
                          if (isPlaying) {
                            widget.audioHandler.pause();
                          } else {
                            widget.audioHandler.play();
                          }
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
