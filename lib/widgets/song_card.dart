import 'package:flutter/material.dart';

class SongCard extends StatelessWidget {
  final double width;
  final String imageUrl;
  final String songName;
  final String artistName;

  const SongCard({
    super.key,
    required this.width,
    required this.imageUrl,
    required this.songName,
    required this.artistName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: width,
          height: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: AssetImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: width,
          child: Text(
            songName,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: width,
          child: Text(
            artistName,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
