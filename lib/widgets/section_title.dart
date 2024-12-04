import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Text(
      title,
      style: TextStyle(
        fontSize: screenSize.width * 0.05,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
