import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/pages/search_page.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:fyp_musicapp_aws/pages/audio_player_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LibraryPage extends StatefulWidget {
  final AudioHandler audioHandler;

  const LibraryPage({
    super.key,
    required this.audioHandler,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final List<Songs> _songs = [];
  final Set<String> _availableGenres = {};
  bool _isLoading = true;
  String? _selectedGenre;
  String _userPreferredFileType = 'mp3'; // Default to mp3
  Songs? _currentPlayingSong;
  bool _isPlaying = false;
  // ignore: prefer_final_fields
  Duration _duration = Duration.zero;
  // ignore: prefer_final_fields
  Duration _position = Duration.zero;

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
        if (mounted) {
          setState(() {
            _userPreferredFileType = userProfile?.preferFileType ?? 'mp3';
          });
        }
      }

      await _loadGenres();
    } catch (e) {
      safePrint('Error loading user preferences: $e');
      await _loadGenres(); // Still load genres with default file type
    }
  }

  Future<void> _loadGenres() async {
    try {
      setState(() => _isLoading = true);

      final allSongsRequest = ModelQueries.list(
        Songs.classType,
        where: Songs.FILETYPE.eq(_userPreferredFileType),
      );
      final allSongsResponse =
          await Amplify.API.query(request: allSongsRequest).response;

      final allSongs = allSongsResponse.data?.items.whereType<Songs>() ?? [];
      final genres = allSongs
          .map((song) => song.genre)
          .where((genre) => genre != null)
          .toSet();

      if (mounted) {
        setState(() {
          _availableGenres.clear();
          _availableGenres.addAll(genres.cast<String>());
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error loading genres: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSongsByGenre(String genre) async {
    try {
      setState(() => _isLoading = true);

      final request = ModelQueries.list(
        Songs.classType,
        where: Songs.GENRE
            .eq(genre)
            .and(Songs.FILETYPE.eq(_userPreferredFileType)),
      );
      final response = await Amplify.API.query(request: request).response;

      if (mounted) {
        setState(() {
          _songs.clear();
          _songs.addAll(response.data?.items.whereType<Songs>() ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error loading songs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playSong(Songs song) async {
    try {
      if (widget.audioHandler.currentSong?.id == song.id) {
        if (widget.audioHandler.isPlaying) {
        } else {
          await widget.audioHandler.play();
        }
        return;
      }

      await _storeHistory(song);
      await widget.audioHandler.playSong(song, _songs);
    } catch (e) {
      safePrint('Error playing song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing song: ${e.toString()}')),
        );
      }
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
    if (_songs.isEmpty || _currentPlayingSong == null) return;

    final currentIndex =
        _songs.indexWhere((s) => s.id == _currentPlayingSong?.id);
    final previousIndex =
        currentIndex <= 0 ? _songs.length - 1 : currentIndex - 1;

    await _playSong(_songs[previousIndex]);
  }

  Future<void> _playNextSong() async {
    if (_songs.isEmpty || _currentPlayingSong == null) return;

    final currentIndex =
        _songs.indexWhere((s) => s.id == _currentPlayingSong?.id);
    final nextIndex = (currentIndex + 1) % _songs.length;

    await _playSong(_songs[nextIndex]);
  }

  void _showPlaylistOptions(Songs song) async {
    final user = await Amplify.Auth.getCurrentUser();

    // Fetch user's playlists
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
      backgroundColor: const Color(0xFF202020),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add, color: Color(0xFFFDFDFD)),
            title: const Text(
              'Create New Playlist',
              style: TextStyle(color: Color(0xFFFDFDFD)),
            ),
            onTap: () {
              Navigator.pop(context);
              _showCreatePlaylistDialog(song);
            },
          ),
          if (playlists.isNotEmpty) const Divider(color: Color(0xFF303030)),
          ...playlists.map((playlist) => ListTile(
                leading:
                    const Icon(Icons.playlist_add, color: Color(0xFFFDFDFD)),
                title: Text(
                  playlist.name ?? 'Untitled Playlist',
                  style: const TextStyle(color: Color(0xFFFDFDFD)),
                ),
                onTap: () async {
                  try {
                    // Check if song already exists in playlist
                    final existingRequest = ModelQueries.list(
                      PlaylistItems.classType,
                      where: PlaylistItems.PLAYLISTID
                          .eq(playlist.id)
                          .and(PlaylistItems.SONGID.eq(song.id)),
                    );
                    final existingResponse = await Amplify.API
                        .query(request: existingRequest)
                        .response;

                    if (existingResponse.data?.items.isEmpty ?? true) {
                      // Add song to playlist
                      final playlistSong = PlaylistItems(
                        PlaylistID: playlist.id,
                        SongID: song.id,
                      );
                      final request = ModelMutations.create(playlistSong);
                      await Amplify.API.mutate(request: request).response;

                      if (mounted) {
                        final currentContext = context;
                        if (currentContext.mounted) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: Text('Added to ${playlist.name}'),
                              backgroundColor: const Color(0xffa91d3a),
                            ),
                          );
                        }
                      }
                    } else {
                      if (mounted) {
                        final currentContext = context;
                        if (currentContext.mounted) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            const SnackBar(
                              content: Text('Song already exists in playlist'),
                              backgroundColor: Color(0xFF303030),
                            ),
                          );
                        }
                      }
                    }
                  } catch (e) {
                    safePrint('Error adding song to playlist: $e');
                    if (mounted) {
                      final currentContext = context;
                      if (currentContext.mounted) {
                        ScaffoldMessenger.of(currentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Error adding song to playlist'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                  if (mounted) {
                    final currentContext = context;
                    if (currentContext.mounted) {
                      Navigator.pop(currentContext);
                    }
                  }
                },
              )),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(Songs song) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text(
          'Create Playlist',
          style: TextStyle(color: Color(0xFFFDFDFD)),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFFDFDFD)),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xffa91d3a)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isEmpty) return;

              try {
                final user = await Amplify.Auth.getCurrentUser();

                // Create new playlist
                final playlist = Playlists(
                  userID: user.userId,
                  name: name,
                );
                final createPlaylistRequest = ModelMutations.create(playlist);
                final playlistResponse = await Amplify.API
                    .mutate(request: createPlaylistRequest)
                    .response;

                // Add song to the new playlist
                if (playlistResponse.data != null) {
                  final playlistSong = PlaylistItems(
                    PlaylistID: playlistResponse.data!.id,
                    SongID: song.id,
                  );
                  final request = ModelMutations.create(playlistSong);
                  await Amplify.API.mutate(request: request).response;

                  if (mounted) {
                    final currentContext = context;
                    if (currentContext.mounted) {
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text('Created playlist "$name" with song'),
                          backgroundColor: const Color(0xffa91d3a),
                        ),
                      );
                    }
                  }
                }
              } catch (e) {
                safePrint('Error creating playlist: $e');
                if (mounted) {
                  final currentContext = context;
                  if (currentContext.mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Error creating playlist'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
              if (mounted) {
                final currentContext = context;
                if (currentContext.mounted) {
                  Navigator.pop(currentContext);
                }
              }
            },
            child: const Text(
              'Create',
              style: TextStyle(color: Color(0xffa91d3a)),
            ),
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
        title: const Text(
          'Library',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(
                    audioHandler: widget.audioHandler,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Genres Section
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF202020),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.library_music,
                          color: Color(0xFFFDFDFD),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Browse by Genre',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFDFDFD),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading && _availableGenres.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: _availableGenres.map((genre) {
                          final isSelected = _selectedGenre == genre;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedGenre = null;
                                    _songs.clear();
                                  } else {
                                    _selectedGenre = genre;
                                    _loadSongsByGenre(genre);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xffa91d3a)
                                      : const Color(0xFF303030),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  genre,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[300],
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            // Songs Section
            if (_selectedGenre != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF202020),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '$_selectedGenre Songs',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFDFDFD),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_songs.length})',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFFFDFDFD),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedGenre = null;
                                _songs.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_songs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.music_off,
                                size: 48,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No ${_userPreferredFileType.toUpperCase()} songs found',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(8),
                        itemCount: _songs.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFF303030),
                        ),
                        itemBuilder: (context, index) {
                          final song = _songs[index];
                          final isCurrentSong =
                              _currentPlayingSong?.id == song.id;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: FutureBuilder<String>(
                              future: widget.audioHandler
                                  .getAlbumArtUrl(song.album ?? 'logo'),
                              builder: (context, snapshot) {
                                return Container(
                                  width: 48,
                                  height: 48,
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
                                    ? const Color(0xffa91d3a)
                                    : const Color(0xFFFDFDFD),
                                fontWeight: isCurrentSong
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              song.artist ?? 'Unknown Artist',
                              style: TextStyle(
                                color: isCurrentSong
                                    ? const Color(0xffa91d3a).withOpacity(0.7)
                                    : Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrentSong)
                                  IconButton(
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: const Color(0xffa91d3a),
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
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Color(0xFFFDFDFD),
                                  ),
                                  onPressed: () {
                                    _showPlaylistOptions(song);
                                  },
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
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF202020),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.library_music,
                        size: 64,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a genre to view songs',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
}
