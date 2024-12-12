import 'package:flutter/material.dart';

class SongCard extends StatelessWidget {
  final double width;
  final double height;
  final String imageUrl;
  final String songName;
  final String artistName;
  final VoidCallback? onOptionsPressed;

  const SongCard({
    super.key,
    required this.width,
    required this.height,
    required this.imageUrl,
    required this.songName,
    required this.artistName,
    this.onOptionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final imageSize = isTablet ? 180.0 : 140.0;
    final titleSize = isTablet ? 16.0 : 14.0;
    final subtitleSize = isTablet ? 14.0 : 12.0;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: imageSize,
            height: imageSize,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: AssetImage(imageUrl),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
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
                      songName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: titleSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artistName,
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
              if (onOptionsPressed != null)
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: onOptionsPressed,
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
