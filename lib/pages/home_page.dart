import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/widgets/song_card.dart';
import 'package:fyp_musicapp_aws/pages/library_page.dart';
import 'package:fyp_musicapp_aws/pages/user_page.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:fyp_musicapp_aws/pages/audio_player_page.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fyp_musicapp_aws/widgets/persistent_mini_player.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:fyp_musicapp_aws/services/lifecycle_handler.dart';
import 'playlist_page.dart';
import 'playlist_details_page.dart';
import 'package:fyp_musicapp_aws/services/playlist_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<Songs?> _recentSongs = [];
  String _userName = 'User';
  Songs? _currentSong;
  bool _isPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AudioHandler _audioHandler;
  late final LifecycleEventHandler _lifecycleObserver;
  late final PlaylistHandler _playlistHandler;

  // Add these properties at the top of the class
  String _preferFileType = 'mp3'; // Default value

  // Add these properties
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Add this property
  final List<Playlists?> _userPlaylists = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = LifecycleEventHandler(_audioPlayer);
    _audioHandler = AudioHandler(_audioPlayer);
    _playlistHandler = PlaylistHandler();
    _setupAudioPlayer();
    _setupPlaylistHandler();
    _checkAmplifyConfig();
    _fetchRecentSongs();
    _fetchUserProfile();
    _playlistHandler.refreshPlaylists();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  void _setupAudioPlayer() {
    _audioHandler.playbackState.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
    });

    _audioHandler.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() => _duration = duration);
      }
    });

    _audioHandler.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _audioHandler.currentSongStream.listen((song) {
      if (mounted) {
        setState(() => _currentSong = song);
      }
    });

    _audioHandler.playingStream.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
      }
    });
  }

  Future<List<Songs?>> queryListItems() async {
    try {
      safePrint('Fetching songs...');

      // Create a query with file type filter
      final request = ModelQueries.list(
        Songs.classType,
        where: Songs.FILETYPE.eq(_preferFileType),
        limit: 10,
      );

      final response = await Amplify.API.query(request: request).response;

      final items = response.data?.items;
      if (items == null || items.isEmpty) {
        safePrint('No songs found with file type: $_preferFileType');
        return <Songs?>[];
      }

      // Debug each song
      for (final song in items) {
        safePrint(
            'Song found: ID=${song?.id}, Title=${song?.title}, FileType=${song?.fileType}');
      }

      return items;
    } on ApiException catch (e) {
      safePrint('API Error: ${e.message}');
      return <Songs?>[];
    }
  }

  Future<void> _fetchRecentSongs() async {
    try {
      final songs = await queryListItems();
      if (mounted) {
        setState(() {
          _recentSongs = songs;
          safePrint('Updated state with ${songs.length} songs');
        });
      }
    } catch (e) {
      safePrint('Error in _fetchRecentSongs: $e');
    }
  }

  Future<void> _checkAmplifyConfig() async {
    try {
      // Check current auth session
      final session = await Amplify.Auth.fetchAuthSession();
      safePrint('Is user signed in: ${session.isSignedIn}');

      // Get current user info
      final user = await Amplify.Auth.getCurrentUser();
      safePrint('Current user ID: ${user.userId}');
    } catch (e) {
      safePrint('Error checking config: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
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
          _userName = userProfile?.name ?? 'User';
          _preferFileType = userProfile?.preferFileType ?? 'mp3';
        });
        // Refresh songs list with new file type preference
        _fetchRecentSongs();
      }
    } catch (e) {
      safePrint('Error fetching user profile: $e');
    }
  }

  // Simplified audio control methods
  Future<void> _playSong(Songs song) async {
    try {
      await _storeHistory(song);
      await _audioHandler.playSong(
          song, _recentSongs.whereType<Songs>().toList());
    } catch (e) {
      safePrint('Error playing song: $e');
      // Show error snackbar
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

  Future<void> _playNextSong() async {
    if (_recentSongs.isEmpty || _currentSong == null) return;

    final currentIndex =
        _recentSongs.indexWhere((s) => s?.id == _currentSong?.id);
    final nextIndex = (currentIndex + 1) % _recentSongs.length;

    if (_recentSongs[nextIndex] != null) {
      await _playSong(_recentSongs[nextIndex]!);
    }
  }

  Future<void> _playPreviousSong() async {
    if (_recentSongs.isEmpty || _currentSong == null) return;

    final currentIndex =
        _recentSongs.indexWhere((s) => s?.id == _currentSong?.id);
    final previousIndex =
        currentIndex <= 0 ? _recentSongs.length - 1 : currentIndex - 1;

    if (_recentSongs[previousIndex] != null) {
      await _playSong(_recentSongs[previousIndex]!);
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> _togglePlayPause(Songs song) async {
    try {
      setState(() => _isPlaying = !_isPlaying); // Update state immediately
      if (_isPlaying) {
        if (_audioPlayer.audioSource == null) {
          await _playSong(song);
        } else {
          await _audioPlayer.play();
        }
      } else {
        await _audioPlayer.pause();
      }
    } catch (e) {
      safePrint('Error toggling playback: $e');
      setState(() => _isPlaying = _audioPlayer.playing); // Revert on error
    }
  }

  void _setupPlaylistHandler() {
    _playlistHandler.playlistsStream.listen((playlists) {
      if (mounted) {
        setState(() {
          _userPlaylists.clear();
          _userPlaylists.addAll(playlists);
        });
      }
    });
  }

  Future<int> _getPlaylistSongCount(String playlistId) async {
    try {
      final request = ModelQueries.list(
        PlaylistItems.classType,
        where: PlaylistItems.PLAYLISTID.eq(playlistId),
      );
      final response = await Amplify.API.query(request: request).response;
      return response.data?.items.length ?? 0;
    } catch (e) {
      safePrint('Error getting playlist song count: $e');
      return 0;
    }
  }

  Future<void> _showAddToPlaylistModal(Songs song) async {
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
          if (_userPlaylists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No playlists found. Create a playlist first.'),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _userPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = _userPlaylists[index];
                  return ListTile(
                    title: Text(playlist?.name ?? 'Untitled Playlist'),
                    onTap: () async {
                      try {
                        // Check for duplicate songs
                        final existingSongsRequest = ModelQueries.list(
                          PlaylistItems.classType,
                          where: PlaylistItems.PLAYLISTID.eq(playlist!.id),
                        );
                        final existingSongsResponse = await Amplify.API
                            .query(request: existingSongsRequest)
                            .response;
                        final existingSongs = existingSongsResponse.data?.items
                                .whereType<PlaylistItems>()
                                .toList() ??
                            [];

                        // Check if song already exists in playlist
                        final isDuplicate =
                            existingSongs.any((item) => item.SongID == song.id);

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
                          SnackBar(content: Text('Added to ${playlist.name}')),
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
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    // Fixed dimensions
    final padding = isTablet ? 24.0 : 16.0;
    final sectionSpacing = isTablet ? 32.0 : 24.0;
    final titleSize = isTablet ? 24.0 : 20.0;
    final logoSize = isTablet ? 48.0 : 36.0;
    final listHeight = isTablet ? 280.0 : 240.0;

    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: padding, vertical: padding / 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'images/logo.png',
                    width: logoSize * 1,
                  ),
                  Row(
                    children: [
                      Text(
                        'Welcome!\n$_userName',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: const Color(0xFFFDFDFD),
                        ),
                        textAlign: TextAlign.end,
                      ),
                      IconButton(
                        icon: const Icon(Icons.person, size: 22),
                        padding: const EdgeInsets.all(8),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserPage(
                              audioHandler: _audioHandler,
                              playlistHandler: _playlistHandler,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  // Home Page
                  ListView(
                    padding: EdgeInsets.all(padding),
                    children: [
                      Text(
                        'Recently Added',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFDFDFD),
                        ),
                      ),
                      SizedBox(height: padding),
                      SizedBox(
                        height: listHeight,
                        child: _recentSongs.isEmpty
                            ? const Center(
                                child: Text(
                                  'No songs available',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recentSongs.length,
                                itemBuilder: (context, index) {
                                  final song = _recentSongs[index];
                                  return GestureDetector(
                                    onTap: () {
                                      if (song != null) {
                                        if (_currentSong?.id != song.id) {
                                          _playSong(song);
                                        }
                                        _showAudioPlayer(song);
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsets.only(right: padding),
                                          child: SongCard(
                                            width: isTablet ? 200 : 160,
                                            height: isTablet ? 260 : 220,
                                            imageUrl: song?.album ?? 'logo',
                                            songName: song?.title ?? 'Unknown',
                                            artistName: song?.artist ??
                                                'Unknown Artist',
                                            audioHandler: _audioHandler,
                                            onOptionsPressed: song != null
                                                ? () {
                                                    showModalBottomSheet(
                                                      context: context,
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF151515),
                                                      builder: (context) =>
                                                          Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          ListTile(
                                                            leading: const Icon(
                                                                Icons
                                                                    .playlist_add),
                                                            title: const Text(
                                                                'Add to Playlist'),
                                                            onTap: () {
                                                              Navigator.pop(
                                                                  context);
                                                              _showAddToPlaylistModal(
                                                                  song);
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      SizedBox(height: sectionSpacing),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Playlists',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFDFDFD),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlaylistPage(
                                    audioHandler: _audioHandler,
                                    playlistHandler: _playlistHandler,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Show All'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFDFDFD),
                              backgroundColor: const Color(0xFF202020),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: padding),
                      _userPlaylists.isEmpty
                          ? const Center(
                              child: Text(
                                'No playlists available',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _userPlaylists.length,
                              itemBuilder: (context, index) {
                                final playlist = _userPlaylists[index];
                                if (playlist == null) {
                                  return const SizedBox.shrink();
                                }

                                return FutureBuilder<int>(
                                  future: _getPlaylistSongCount(playlist.id),
                                  builder: (context, snapshot) {
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 4),
                                      leading: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF303030),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.queue_music_rounded,
                                          color: Color(0xff909090),
                                        ),
                                      ),
                                      title: Text(
                                        playlist.name ?? 'Untitled Playlist',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${snapshot.data ?? 0} songs',
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlaylistDetailsPage(
                                              playlist: playlist,
                                              audioHandler: _audioHandler,
                                              playlistHandler: _playlistHandler,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                  // Library Page
                  LibraryPage(audioHandler: _audioHandler),
                  // Profile Page
                  UserPage(
                    audioHandler: _audioHandler,
                    playlistHandler: _playlistHandler,
                  ),
                ],
              ),
            ),
            // Mini Player and Navigation
            if (_currentSong != null)
              PersistentMiniPlayer(
                audioHandler: _audioHandler,
                currentSong: _currentSong,
                isPlaying: _isPlaying,
                onTap: () {
                  if (_currentSong != null) {
                    _showAudioPlayer(_currentSong!);
                  }
                },
                onPlayPause: () {
                  if (_currentSong != null) {
                    _togglePlayPause(_currentSong!);
                  }
                },
              ),
            Container(
              color: const Color(0xFF151515),
              child: BottomNavigationBar(
                backgroundColor: const Color(0xFF151515),
                fixedColor: const Color(0xffa91d3a),
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.library_music),
                    label: 'Library',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
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
        audioHandler: _audioHandler,
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _playlistHandler.dispose();
    super.dispose();
  }
}
