import 'package:flutter/material.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Profile'),
      ),
      body: ListView(
        children: [
          // User Profile Section
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 20),
          const Text(
            'User Name',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),

          // Tile List
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('My Playlists'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to playlists
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Listening History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to history
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to settings
            },
          ),
        ],
      ),
    );
  }
}
