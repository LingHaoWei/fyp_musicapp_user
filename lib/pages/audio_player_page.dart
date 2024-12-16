import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  Future<void> _loadAlbumArt() async {
    final album = _currentSong.album;
    if (album != null) {
      _cachedAlbumArtUrl = await widget.audioHandler.getAlbumArtUrl(album);
      if (mounted) setState(() {});
    }
  }

  void _setupPlayerListeners() {
    widget.audioHandler.playbackState.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading = state.processingState == ProcessingState.loading;
        });
      }
    });

    widget.audioHandler.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _duration = duration);
      }
    });

    widget.audioHandler.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    widget.audioHandler.currentSongStream.listen((song) {
      if (mounted && song != null) {
        setState(() => _currentSong = song);
      }
    });
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
    return DraggableScrollableSheet(
      controller: _dragController,
      initialChildSize: 1.0,
      minChildSize: 0.1,
      maxChildSize: 1.0,
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
              // Drag handle - only show in full view
              if (!isMinimized)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: isMinimized
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  child: isMinimized
                      ? _buildMiniPlayer()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(height: 20),
                            _buildAlbumArt(),
                            const SizedBox(height: 40),
                            _buildSongInfo(),
                            const SizedBox(height: 40),
                            _buildProgressBar(),
                            const SizedBox(height: 40),
                            _buildControls(),
                            const SizedBox(height: 40),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      height: 60,
      color: const Color(0xFF151515),
      child: Row(
        children: [
          // Album art
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                          imageUrl: _cachedAlbumArtUrl!,
                          fit: BoxFit.cover,
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
    return Center(
      child: Container(
        width: 280,
        height: 280,
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
        child: _cachedAlbumArtUrl == null
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            : _cachedAlbumArtUrl!.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.music_note, size: 80),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: _cachedAlbumArtUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.error),
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
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _currentSong.artist ?? 'Unknown Artist',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position)),
                Text(_formatDuration(_duration)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle button
        StreamBuilder<bool>(
          stream: widget.audioHandler.shuffleModeStream,
          builder: (context, snapshot) {
            final isShuffling = snapshot.data ?? false;
            return IconButton(
              iconSize: 30,
              icon: Icon(
                Icons.shuffle,
                color: isShuffling ? Colors.blue : Colors.white,
              ),
              onPressed: () => widget.audioHandler.setShuffleMode(!isShuffling),
            );
          },
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous),
          onPressed: () {
            widget.onPreviousSong();
            setState(() {
              _currentSong = widget.song;
              _isPlaying = widget.isPlaying;
            });
          },
        ),
        const SizedBox(width: 20),
        IconButton(
          iconSize: 72,
          icon: Icon(
            _isLoading
                ? Icons.hourglass_empty
                : (_isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled),
            color: Colors.white,
          ),
          onPressed: _isLoading ? null : _onPlayPause,
        ),
        const SizedBox(width: 20),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next),
          onPressed: () {
            widget.onNextSong();
            setState(() {
              _currentSong = widget.song;
              _isPlaying = widget.isPlaying;
            });
          },
        ),
        // Loop button
        StreamBuilder<LoopMode>(
          stream: widget.audioHandler.loopModeStream,
          builder: (context, snapshot) {
            final loopMode = snapshot.data ?? LoopMode.off;
            IconData icon;
            Color? color;

            switch (loopMode) {
              case LoopMode.off:
                icon = Icons.repeat;
                color = Colors.white;
                break;
              case LoopMode.one:
                icon = Icons.repeat_one;
                color = Colors.blue;
                break;
              case LoopMode.all:
                icon = Icons.repeat;
                color = Colors.blue;
                break;
            }

            return IconButton(
              iconSize: 30,
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
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
