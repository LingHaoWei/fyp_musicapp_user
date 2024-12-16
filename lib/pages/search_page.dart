import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';
import 'dart:async';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:fyp_musicapp_aws/pages/audio_player_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    // Auto focus the search field when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
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
      await _storeHistory(song);
      await widget.audioHandler.playSong(song, _searchResults);
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
                onPlayStateChanged: (isPlaying) {
                  if (isPlaying) {
                    widget.audioHandler.play();
                  } else {
                    widget.audioHandler.pause();
                  }
                },
                onPreviousSong: _playPreviousSong,
                onNextSong: _playNextSong,
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

  Future<void> _playPreviousSong() async {
    if (_searchResults.isEmpty || widget.audioHandler.currentSong == null) {
      return;
    }

    final currentIndex = _searchResults
        .indexWhere((s) => s.id == widget.audioHandler.currentSong?.id);
    final previousIndex =
        currentIndex <= 0 ? _searchResults.length - 1 : currentIndex - 1;

    if (previousIndex >= 0) {
      await _playSong(_searchResults[previousIndex]);
    }
  }

  Future<void> _playNextSong() async {
    if (_searchResults.isEmpty || widget.audioHandler.currentSong == null) {
      return;
    }

    final currentIndex = _searchResults
        .indexWhere((s) => s.id == widget.audioHandler.currentSong?.id);
    final nextIndex = (currentIndex + 1) % _searchResults.length;

    await _playSong(_searchResults[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Songs?>(
      stream: widget.audioHandler.currentSongStream,
      builder: (context, songSnapshot) {
        return StreamBuilder<bool>(
          stream: widget.audioHandler.playingStream,
          builder: (context, playingSnapshot) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF202020),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search songs...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchText = '';
                                  _searchResults.clear();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
              body: Column(
                children: [
                  if (_searchText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Results for "$_searchText"',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_isLoading)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading && _searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchText.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Search for songs',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find your favorite songs by title or artist',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchText"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final song = _searchResults[index];
        final isCurrentSong = widget.audioHandler.currentSong?.id == song.id;
        final isPlaying = isCurrentSong && widget.audioHandler.isPlaying;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrentSong ? const Color(0xFF202020) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: Hero(
              tag: 'album_art_${song.id}',
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FutureBuilder<String>(
                  future:
                      widget.audioHandler.getAlbumArtUrl(song.album ?? 'logo'),
                  builder: (context, snapshot) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: !snapshot.hasData
                          ? Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: snapshot.data!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[800],
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.music_note),
                              ),
                            ),
                    );
                  },
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
            subtitle: Text(
              song.artist ?? 'Unknown Artist',
              style: TextStyle(
                color: isCurrentSong
                    ? Theme.of(context).primaryColor.withOpacity(0.7)
                    : Colors.grey,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrentSong)
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        widget.audioHandler.pause();
                      } else {
                        widget.audioHandler.play();
                      }
                    },
                  ),
                IconButton(
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
              ],
            ),
            onTap: () {
              if (widget.audioHandler.currentSong?.id != song.id) {
                _playSong(song);
              }
              _showAudioPlayer(song);
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
