import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/theme/app_color.dart';
import 'package:fyp_musicapp_aws/widgets/song_card.dart';
import 'package:fyp_musicapp_aws/widgets/section_title.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final double _padding;
  List<Songs?> _recentSongs = [];
  String _userName = 'User';
  Songs? _currentSong;
  bool _isPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AudioHandler _audioHandler;
  late final LifecycleEventHandler _lifecycleObserver;

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
    _padding = MediaQuery.of(context).size.width * 0.04;
  }

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = LifecycleEventHandler(_audioPlayer);
    _audioHandler = AudioHandler(_audioPlayer);
    _setupAudioPlayer();
    _checkAmplifyConfig();
    _fetchRecentSongs();
    _fetchUserProfile();
    _fetchUserPlaylists();
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

  Widget _buildRecentlyPlayedItemCard(BuildContext context, int index) {
    final screenSize = MediaQuery.of(context).size;
    final song = _recentSongs[index];
    final album = song?.album;

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
            padding: EdgeInsets.only(right: _padding),
            child: SongCard(
              width: screenSize.width * 0.3,
              imageUrl: 'images/${album ?? 'logo'}.png',
              songName: song?.title ?? 'Untitled',
              artistName: song?.artist ?? 'Unknown Artist',
            ),
          ),
          Positioned(
            bottom: 0,
            right: _padding,
            child: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                if (song != null) {
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
                }
              },
            ),
          ),
        ],
      ),
    );
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
      if (_currentSong?.id == song.id) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
          setState(() => _isPlaying = false);
        } else {
          await _audioPlayer.play();
          setState(() => _isPlaying = true);
        }
        return;
      }

      setState(() => _isPlaying = true); // Set playing state before loading
      _currentSong = song;
      await _audioPlayer.stop();

      final result = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(
            'public/songs/$_preferFileType/${song.title}'),
        options: const StorageGetUrlOptions(),
      ).result;

      await _audioPlayer.setUrl(result.url.toString());
      await _storeHistory(song);
      await _audioPlayer.play();
    } catch (e) {
      safePrint('Error playing song: $e');
      setState(() => _isPlaying = false); // Reset state on error
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

  Future<void> _fetchUserPlaylists() async {
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
          _userPlaylists.clear(); // Clear existing playlists
          _userPlaylists
              .addAll(items?.whereType<Playlists>() ?? []); // Add new playlists
        });
      }
    } catch (e) {
      safePrint('Error fetching playlists: $e');
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

  Future<void> _renamePlaylist(Playlists playlist) async {
    final TextEditingController nameController =
        TextEditingController(text: playlist.name);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: nameController,
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
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  final updatedPlaylist = playlist.copyWith(name: newName);
                  final request = ModelMutations.update(updatedPlaylist);
                  await Amplify.API.mutate(request: request).response;

                  _fetchUserPlaylists(); // Refresh the playlists
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                          content: Text('Playlist renamed successfully')),
                    );
                  }
                } catch (e) {
                  safePrint('Error renaming playlist: $e');
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Error renaming playlist')),
                    );
                  }
                }
              }
            },
            child: const Text(
              'Rename',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist(Playlists playlist) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF202020),
            title: const Text('Delete Playlist'),
            content:
                Text('Are you sure you want to delete "${playlist.name}"?'),
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
        ) ??
        false;

    if (confirm && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
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
            final deleteItemRequest =
                ModelMutations.delete<PlaylistItems>(item);
            await Amplify.API.mutate(request: deleteItemRequest).response;
          }
        }

        // Then delete the playlist
        final deleteRequest = ModelMutations.delete(playlist);
        await Amplify.API.mutate(request: deleteRequest).response;

        _fetchUserPlaylists(); // Refresh the playlists

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Playlist deleted successfully')),
          );
        }
      } catch (e) {
        safePrint('Error deleting playlist: $e');
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Error deleting playlist')),
          );
        }
      }
    }
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
                _renamePlaylist(playlist);
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
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset(
              'images/logo.png',
              width: screenSize.width * 0.08,
            ),
            Row(
              children: [
                Text(
                  'Good Day!\n$_userName',
                  style: const TextStyle(fontSize: 14),
                ),
                IconButton(
                  onPressed: () => {},
                  icon: const Icon(Icons.person),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(_padding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Recently Added Section
                        const SectionTitle(title: 'Recently Added'),
                        SizedBox(height: _padding),
                        SizedBox(
                          height: screenSize.height * 0.22,
                          child: ListView.builder(
                            itemCount: _recentSongs.length,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: _buildRecentlyPlayedItemCard,
                          ),
                        ),

                        // Playlists Section
                        SizedBox(height: _padding * 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionTitle(title: 'Playlists'),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlaylistPage(
                                      audioHandler: _audioHandler,
                                    ),
                                  ),
                                );
                              },
                              label: const Text(
                                'Show All',
                                style: TextStyle(color: Color(0xfffdfdfd)),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF202020),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _padding),
                        _userPlaylists.isEmpty
                            ? Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF151515),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.queue_music,
                                      size: 48,
                                      color: Color(0xffa91d3a),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Create Your First Playlist',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Organize your favorite songs',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PlaylistPage(
                                                audioHandler: _audioHandler),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text(
                                        'Create Playlist',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(),
                                    ),
                                  ],
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

                                  return Card(
                                    color: const Color(0xFF151515),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(12),
                                      leading: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF303030),
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                        onPressed: () =>
                                            _showPlaylistOptions(playlist),
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlaylistDetailsPage(
                                                    playlist: playlist,
                                                    audioHandler:
                                                        _audioHandler),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ]),
                    ),
                  ),
                ],
              ),
              LibraryPage(audioHandler: _audioHandler),
              UserPage(audioHandler: _audioHandler),
            ],
          ),
          // Add persistent mini player at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentSong != null)
                  PersistentMiniPlayer(
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
                // Add bottom navigation bar with padding if mini player is showing
                Container(
                  color: const Color(0xFF151515),
                  child: BottomNavigationBar(
                    backgroundColor: Colors.transparent,
                    fixedColor: AppColor.primaryColor,
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
                        label: 'User',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    super.dispose();
  }
}
