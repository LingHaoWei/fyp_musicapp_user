import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';

class PersistentMiniPlayer extends StatefulWidget {
  final Songs? currentSong;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final AudioHandler audioHandler;

  const PersistentMiniPlayer({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    required this.audioHandler,
  });

  @override
  State<PersistentMiniPlayer> createState() => _PersistentMiniPlayerState();
}

class _PersistentMiniPlayerState extends State<PersistentMiniPlayer> {
  String? _cachedAlbumArtUrl;

  @override
  void initState() {
    super.initState();
    _loadAlbumArt();
  }

  @override
  void didUpdateWidget(PersistentMiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSong?.album != widget.currentSong?.album) {
      _loadAlbumArt();
    }
  }

  Future<void> _loadAlbumArt() async {
    if (widget.currentSong?.album != null) {
      _cachedAlbumArtUrl =
          await widget.audioHandler.getAlbumArtUrl(widget.currentSong!.album!);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentSong == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.currentSong?.title ?? 'Unknown Title',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.currentSong?.artist ?? 'Unknown Artist',
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    widget.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: widget.onPlayPause,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
