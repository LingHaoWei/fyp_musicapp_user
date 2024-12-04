import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/main.dart';
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

// Add this before the HomePage class
class LifecycleEventHandler extends WidgetsBindingObserver {
  final AudioPlayer audioPlayer;

  LifecycleEventHandler(this.audioPlayer);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      audioPlayer.stop();
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Cache MediaQuery values
  late final double _padding;

  List<Songs?> _recentSongs = [];

  String _userName = 'User';

  Songs? _currentSong;
  bool _isPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Update the observer initialization
  late final LifecycleEventHandler _lifecycleObserver;

  // Add these properties at the top of the class
  String _preferFileType = ''; // Default value

  // Add these properties
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _padding = MediaQuery.of(context).size.width * 0.04;
  }

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = LifecycleEventHandler(_audioPlayer);
    _setupAudioPlayer();
    _checkAmplifyConfig();
    _fetchRecentSongs();
    _fetchUserProfile();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  // Update the _setupAudioPlayer method
  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });

    // Add these listeners
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() => _duration = duration);
      }
    });

    _audioPlayer.positionStream.listen((position) {
      setState(() => _position = position);
    });

    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _playNextSong();
      }
    });
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Amplify.Auth.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MyApp()),
      );
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('Sign out failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign out failed. Please try again.')),
      );
    }
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

  Widget _buildRecentlyPlayedItem(BuildContext context, int index) {
    final screenSize = MediaQuery.of(context).size;
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
      child: Padding(
        padding: EdgeInsets.only(right: _padding),
        child: SongCard(
          width: screenSize.width * 0.3,
          imageUrl: 'images/logo.png',
          songName: song?.title ?? 'Untitled',
          artistName: song?.artist ?? 'Unknown Artist',
        ),
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
      // If same song, just toggle play/pause
      if (_currentSong?.id == song.id) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
        return;
      }

      // New song, load and play
      _currentSong = song;
      await _audioPlayer.stop();

      final result = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(
            'public/songs/$_preferFileType/${song.title}'),
        options: const StorageGetUrlOptions(),
      ).result;

      await _audioPlayer.setUrl(result.url.toString());
      await _audioPlayer.play();
      setState(() => _isPlaying = true);
    } catch (e) {
      safePrint('Error playing song: $e');
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
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_audioPlayer.audioSource == null) {
          await _playSong(song);
        } else {
          await _audioPlayer.play();
        }
      }
      setState(() => _isPlaying = !_isPlaying);
    } catch (e) {
      safePrint('Error toggling playback: $e');
    }
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
              width: screenSize.width * 0.09, // 10% of screen width
            ),
            Row(
              children: [
                Text(
                  'Good Day!\n$_userName',
                  style: const TextStyle(fontSize: 14),
                ),
                IconButton(
                  onPressed: () => _signOut(context),
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
                // Replace SingleChildScrollView with CustomScrollView
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(_padding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SectionTitle(title: 'Recently Added'),
                        SizedBox(height: _padding),
                        SizedBox(
                          height: screenSize.height * 0.22,
                          child: ListView.builder(
                            itemCount: _recentSongs.length,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: _buildRecentlyPlayedItem,
                          ),
                        ),
                        // Trending Now Section
                        SizedBox(height: _padding * 2),
                        const SectionTitle(title: 'Trending Now'),
                        SizedBox(height: _padding),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentSongs.length,
                          itemBuilder: (context, index) {
                            final song = _recentSongs[index];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                vertical: _padding * 0.5,
                                horizontal: 0,
                              ),
                              leading: Container(
                                width: screenSize.width * 0.10,
                                height: screenSize.width * 0.10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  image: const DecorationImage(
                                    image: AssetImage('images/logo.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              title: Text(
                                song?.title ?? 'Untitled',
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song?.artist ?? 'Unknown Artist',
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () {},
                              ),
                            );
                          },
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
              const LibraryPage(),
              // Add a placeholder for the User page
              const UserPage(),
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
        audioPlayer: _audioPlayer,
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
