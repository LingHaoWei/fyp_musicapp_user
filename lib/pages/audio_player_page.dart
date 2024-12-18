import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';

class AudioPlayerPage extends StatefulWidget {
  final Songs song;
  final AudioHandler audioHandler;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
  final Function(bool) onPlayStateChanged;
  final VoidCallback onPreviousSong;
  final VoidCallback onNextSong;

  const AudioPlayerPage({
    super.key,
    required this.song,
    required this.audioHandler,
    required this.isPlaying,
    required this.duration,
    required this.position,
    required this.onPlayStateChanged,
    required this.onPreviousSong,
    required this.onNextSong,
  });

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration? _duration;
  Duration _position = Duration.zero;
  final DraggableScrollableController _dragController =
      DraggableScrollableController();
  bool _isSheetAttached = false;
  late Songs _currentSong;
  String? _cachedAlbumArtUrl;
  bool _isDragging = false;
  late StreamSubscription _playbackSubscription;
  late StreamSubscription _durationSubscription;
  late StreamSubscription _positionSubscription;
  late StreamSubscription _currentSongSubscription;

  @override
  void initState() {
    super.initState();
    _currentSong = widget.song;
    _isPlaying = widget.isPlaying;
    _setupPlayerListeners();
    _loadAlbumArt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _isSheetAttached = true);
    });
  }

  @override
  void didUpdateWidget(AudioPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _currentSong = widget.song;
      _loadAlbumArt();
    }
  }

  void _setupPlayerListeners() {
    _playbackSubscription = widget.audioHandler.playbackState.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading = state.processingState == ProcessingState.loading;
        });
      }
    });

    _durationSubscription =
        widget.audioHandler.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _duration = duration);
      }
    });

    _positionSubscription =
        widget.audioHandler.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _currentSongSubscription =
        widget.audioHandler.currentSongStream.listen((song) {
      if (mounted && song != null) {
        setState(() {
          _currentSong = song;
          _loadAlbumArt();
        });
      }
    });
  }

  @override
  void dispose() {
    _playbackSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();
    _currentSongSubscription.cancel();
    _dragController.dispose();
    super.dispose();
  }

  Future<void> _loadAlbumArt() async {
    if (_currentSong.album != null) {
      _cachedAlbumArtUrl =
          await widget.audioHandler.getAlbumArtUrl(_currentSong.album!);
      if (mounted) setState(() {});
    }
  }

  void _seekTo(Duration position) {
    widget.audioHandler.seekTo(position);
  }

  void _onPlayPause() async {
    if (_isPlaying) {
      await widget.audioHandler.pause();
    } else {
      await widget.audioHandler.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        setState(() {
          _isDragging =
              notification.extent != 1.0 && notification.extent != 0.1;
        });
        return true;
      },
      child: DraggableScrollableSheet(
        controller: _dragController,
        initialChildSize: 1.0,
        minChildSize: 0.1,
        maxChildSize: 1.0,
        snapSizes: const [0.1, 1.0],
        snap: true,
        snapAnimationDuration: const Duration(milliseconds: 300),
        builder: (context, scrollController) {
          final isMinimized = _isSheetAttached && _dragController.size < 0.5;

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isMinimized ? 0 : 20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMinimized)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: isMinimized
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isMinimized
                          ? _buildMiniPlayer()
                          : Column(
                              key: const ValueKey('full_player'),
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const SizedBox(height: 48),
                                if (!_isDragging) _buildAlbumArt(),
                                const SizedBox(height: 24),
                                _buildSongInfo(),
                                const SizedBox(height: 24),
                                _buildProgressBar(),
                                const SizedBox(height: 48),
                                _buildControls(),
                                const SizedBox(height: 32),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      key: const ValueKey('mini_player'),
      height: 60,
      color: const Color(0xFF151515),
      child: Row(
        children: [
          // Album art
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Hero(
              tag: 'album_art_${_currentSong.id}',
              child: _cachedAlbumArtUrl == null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : _cachedAlbumArtUrl!.isEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.music_note, size: 20),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            key: ValueKey(_cachedAlbumArtUrl),
                            imageUrl: _cachedAlbumArtUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 80, // 2x of display size
                            memCacheHeight: 80,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
            ),
          ),
          // Song info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentSong.title ?? 'Unknown Title',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _currentSong.artist ?? 'Unknown Artist',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: _onPlayPause,
              ),
              IconButton(
                icon: const Icon(
                  Icons.skip_next,
                  color: Colors.white,
                ),
                onPressed: () {
                  // Implement next track
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = screenWidth * 0.65; // Reduced from 0.75 to 0.65

    return Center(
      child: Container(
        width: artSize,
        height: artSize,
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Hero(
          tag: 'album_art_${_currentSong.id}',
          child: _cachedAlbumArtUrl == null
              ? Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF202020),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xffa91d3a),
                      ),
                    ),
                  ),
                )
              : _cachedAlbumArtUrl!.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF202020),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: 80,
                        color: Color(0xffa91d3a),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            key: ValueKey(_cachedAlbumArtUrl),
                            imageUrl: _cachedAlbumArtUrl!,
                            fit: BoxFit.cover,
                            width: artSize,
                            height: artSize,
                            memCacheWidth: (artSize * 2).toInt(),
                            memCacheHeight: (artSize * 2).toInt(),
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF202020),
                              child: const Center(
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xffa91d3a),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF202020),
                              child: const Icon(
                                Icons.error,
                                color: Color(0xffa91d3a),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.2),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.2),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            _currentSong.title ?? 'Unknown Title',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFDFDFD),
                  fontSize: 24,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _currentSong.artist ?? 'Unknown Artist',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
                pressedElevation: 8,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 16,
              ),
              activeTrackColor: const Color(0xffa91d3a),
              inactiveTrackColor: Colors.grey[800],
              thumbColor: const Color(0xffa91d3a),
              overlayColor: const Color(0xffa91d3a).withOpacity(0.2),
            ),
            child: Slider(
              value: _position.inSeconds.toDouble(),
              max: (_duration?.inSeconds ?? 0).toDouble(),
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                _seekTo(position);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _showPlaylistOptions,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFDFDFD),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    backgroundColor: const Color(0xFF202020),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(
                    Icons.playlist_add,
                    size: 20,
                  ),
                  label: const Text(
                    'Add to Playlist',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaylistOptions() async {
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
              _showCreatePlaylistDialog();
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
                          .and(PlaylistItems.SONGID.eq(_currentSong.id)),
                    );
                    final existingResponse = await Amplify.API
                        .query(request: existingRequest)
                        .response;

                    if (existingResponse.data?.items.isEmpty ?? true) {
                      // Add song to playlist
                      final playlistSong = PlaylistItems(
                        PlaylistID: playlist.id,
                        SongID: _currentSong.id,
                      );
                      final request = ModelMutations.create(playlistSong);
                      await Amplify.API.mutate(request: request).response;

                      if (mounted) {
                        final currentContext = context;
                        if (currentContext.mounted) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added to ${playlist.name}',
                                style: const TextStyle(
                                  color: Color(0xFFFDFDFD),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
                              content: Text(
                                'Song already exists in playlist',
                                style: TextStyle(
                                  color: Color(0xFFFDFDFD),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
                            content: Text(
                              'Error adding song to playlist',
                              style: TextStyle(
                                color: Color(0xFFFDFDFD),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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

  void _showCreatePlaylistDialog() {
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
                    SongID: _currentSong.id,
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

  Widget _buildControls() {
    const double mainButtonSize = 72;
    const double sideButtonSize = 36;
    const double secondaryButtonSize = 24;
    const Color activeColor = Color(0xffa91d3a);
    const Color inactiveColor = Color(0xFFFDFDFD);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle button
          StreamBuilder<bool>(
            stream: widget.audioHandler.shuffleModeStream,
            builder: (context, snapshot) {
              final isShuffling = snapshot.data ?? false;
              return IconButton(
                iconSize: secondaryButtonSize,
                icon: Icon(
                  Icons.shuffle,
                  color: isShuffling ? activeColor : inactiveColor,
                ),
                onPressed: () =>
                    widget.audioHandler.setShuffleMode(!isShuffling),
              );
            },
          ),
          IconButton(
            iconSize: sideButtonSize,
            icon: const Icon(
              Icons.skip_previous,
              color: inactiveColor,
            ),
            onPressed: widget.onPreviousSong,
          ),
          Container(
            width: mainButtonSize,
            height: mainButtonSize,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
              boxShadow: [
                BoxShadow(
                  color: activeColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              iconSize: mainButtonSize * 0.5,
              icon: Icon(
                _isLoading
                    ? Icons.hourglass_empty
                    : (_isPlaying ? Icons.pause : Icons.play_arrow),
                color: Colors.white,
              ),
              onPressed: _isLoading ? null : _onPlayPause,
            ),
          ),
          IconButton(
            iconSize: sideButtonSize,
            icon: const Icon(
              Icons.skip_next,
              color: inactiveColor,
            ),
            onPressed: widget.onNextSong,
          ),
          // Loop button
          StreamBuilder<LoopMode>(
            stream: widget.audioHandler.loopModeStream,
            builder: (context, snapshot) {
              final loopMode = snapshot.data ?? LoopMode.off;
              IconData icon;
              Color color;

              switch (loopMode) {
                case LoopMode.off:
                  icon = Icons.repeat;
                  color = inactiveColor;
                  break;
                case LoopMode.one:
                  icon = Icons.repeat_one;
                  color = activeColor;
                  break;
                case LoopMode.all:
                  icon = Icons.repeat;
                  color = activeColor;
                  break;
              }

              return IconButton(
                iconSize: secondaryButtonSize,
                icon: Icon(icon, color: color),
                onPressed: () {
                  final nextMode = {
                    LoopMode.off: LoopMode.all,
                    LoopMode.all: LoopMode.one,
                    LoopMode.one: LoopMode.off,
                  }[loopMode]!;
                  widget.audioHandler.setLoopMode(nextMode);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
