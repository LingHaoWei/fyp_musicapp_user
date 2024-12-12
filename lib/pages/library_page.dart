import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/widgets/section_title.dart';
import 'package:fyp_musicapp_aws/pages/search_page.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:fyp_musicapp_aws/pages/audio_player_page.dart';

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
  bool _showAllGenres = false;
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
      final userAttributes = await Amplify.Auth.fetchUserAttributes();

      // Get user's preferred file type from custom attribute
      final preferredFileType = userAttributes
          .firstWhere(
            (element) =>
                element.userAttributeKey.key == 'custom:preferred_file_type',
            orElse: () => const AuthUserAttribute(
              userAttributeKey:
                  CognitoUserAttributeKey.custom('preferred_file_type'),
              value: 'mp3',
            ),
          )
          .value;

      if (mounted) {
        setState(() {
          _userPreferredFileType = preferredFileType;
        });
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

  Color _getGenreColor(String genre) {
    final hash = genre.hashCode;
    return Color.fromARGB(
      255,
      (hash & 0xFF0000) >> 16,
      (hash & 0x00FF00) >> 8,
      hash & 0x0000FF,
    );
  }

  Widget _buildGenreChip(String genre) {
    final isSelected = _selectedGenre == genre;
    final color = _getGenreColor(genre);

    return GestureDetector(
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          genre,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = screenSize.width * 0.04;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Music Library'),
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
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(padding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionTitle(title: 'Genres'),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAllGenres = !_showAllGenres;
                        });
                      },
                      icon: Icon(_showAllGenres
                          ? Icons.expand_less
                          : Icons.expand_more),
                      label: Text(_showAllGenres ? 'Show Less' : 'Show All'),
                    ),
                  ],
                ),
                SizedBox(height: padding),
                if (_isLoading && _availableGenres.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableGenres
                        .take(_showAllGenres ? _availableGenres.length : 4)
                        .map(_buildGenreChip)
                        .toList(),
                  ),
                if (_selectedGenre != null) ...[
                  SizedBox(height: padding * 2),
                  Text(
                    'Songs in $_selectedGenre',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: padding),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_songs.isEmpty)
                    Center(
                      child: Text(
                        'No ${_userPreferredFileType.toUpperCase()} songs found in $_selectedGenre genre',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: DecorationImage(
                                image: AssetImage(
                                    'images/${song.album ?? 'logo'}.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(song.title ?? 'Unknown Title'),
                          subtitle: Text(song.artist ?? 'Unknown Artist'),
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
              ]),
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
