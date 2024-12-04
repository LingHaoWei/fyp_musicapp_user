import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';

class PersistentMiniPlayer extends StatelessWidget {
  final Songs? currentSong;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const PersistentMiniPlayer({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    if (currentSong == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                image: const DecorationImage(
                  image: AssetImage('images/logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentSong?.title ?? 'Unknown Title',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentSong?.artist ?? 'Unknown Artist',
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
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: onPlayPause,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
