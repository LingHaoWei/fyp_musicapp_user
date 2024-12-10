import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/widgets/section_title.dart';
import 'package:fyp_musicapp_aws/pages/search_page.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';

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
      final title = song.title;
      if (title == null) return;

      final url = await Amplify.Storage.getUrl(
        path: StoragePath.fromString('public/songs/${song.fileType}/$title'),
        options: const StorageGetUrlOptions(),
      ).result;

      await widget.audioHandler.playSong(song, url.url.toString());
    } catch (e) {
      safePrint('Error playing song: $e');
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
                          onTap: () => _playSong(song),
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
}
