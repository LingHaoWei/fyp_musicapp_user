import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SongCard extends StatefulWidget {
  final double width;
  final double height;
  final String imageUrl;
  final String songName;
  final String artistName;
  final VoidCallback? onOptionsPressed;
  final AudioHandler audioHandler;

  const SongCard({
    super.key,
    required this.width,
    required this.height,
    required this.imageUrl,
    required this.songName,
    required this.artistName,
    required this.audioHandler,
    this.onOptionsPressed,
  });

  @override
  State<SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<SongCard> {
  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final imageSize = isTablet ? 180.0 : 140.0;
    final titleSize = isTablet ? 16.0 : 14.0;
    final subtitleSize = isTablet ? 14.0 : 12.0;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: imageSize,
            height: imageSize,
            child: FutureBuilder<String>(
              future: widget.audioHandler.getAlbumArtUrl(widget.imageUrl),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.data!.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.music_note, size: 50),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: snapshot.data!,
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
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.songName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: titleSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.artistName,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: subtitleSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.onOptionsPressed != null)
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: widget.onOptionsPressed,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
