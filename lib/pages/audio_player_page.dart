import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

class AudioPlayerPage extends StatefulWidget {
  final Songs song;
  final AudioPlayer audioPlayer;
  final Function(bool) onPlayStateChanged;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
  final VoidCallback onPreviousSong;
  final VoidCallback onNextSong;

  const AudioPlayerPage({
    super.key,
    required this.song,
    required this.audioPlayer,
    required this.onPlayStateChanged,
    required this.isPlaying,
    required this.duration,
    required this.position,
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

  // Add throttling for position updates
  static const _positionUpdateInterval = Duration(milliseconds: 500);
  Timer? _positionUpdateTimer;

  @override
  void initState() {
    super.initState();
    _currentSong = widget.song;
    _isPlaying = widget.isPlaying;
    _setupPlayerListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _isSheetAttached = true);
    });
  }

  @override
  void didUpdateWidget(AudioPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.song.id != oldWidget.song.id) {
      setState(() {
        _currentSong = widget.song;
        _isPlaying = widget.isPlaying;
        _duration = widget.duration;
        _position = widget.position;
      });
    } else {
      setState(() {
        _isPlaying = widget.isPlaying;
      });
    }
  }

  void _setupPlayerListeners() {
    widget.audioPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return;
      setState(() {
        _isPlaying = playerState.playing;
        _isLoading = playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering;
        widget.onPlayStateChanged(_isPlaying);
      });
    });

    widget.audioPlayer.positionStream
        .throttleTime(_positionUpdateInterval)
        .listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });

    widget.audioPlayer.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    _dragController.dispose();
    super.dispose();
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
                  child: isMinimized ? _buildMiniPlayer() : _buildFullPlayer(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    final album = _currentSong.album;
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              image: DecorationImage(
                image: AssetImage('images/${album ?? 'logo'}.png'),
                fit: BoxFit.cover,
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
                onPressed: () {
                  if (_isPlaying) {
                    widget.audioPlayer.pause();
                  } else {
                    widget.audioPlayer.play();
                  }
                },
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

  Widget _buildFullPlayer() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(height: 32),
        _buildAlbumArt(),
        const SizedBox(height: 32),
        _buildSongInfo(),
        const SizedBox(height: 32),
        _buildProgressBar(),
        const SizedBox(height: 32),
        _buildControls(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAlbumArt() {
    final album = _currentSong.album;
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        image: DecorationImage(
          image: AssetImage('images/${album ?? 'logo'}.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
                await widget.audioPlayer.seek(position);
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
          iconSize: 64,
          icon: Icon(
            _isLoading
                ? Icons.hourglass_empty
                : (_isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled),
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  if (_isPlaying) {
                    await widget.audioPlayer.pause();
                  } else {
                    await widget.audioPlayer.play();
                  }
                },
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
