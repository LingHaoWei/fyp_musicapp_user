import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import '../models/Users.dart';
import 'settings_page.dart';
import '../main.dart';
import 'history_page.dart';
import 'playlist_page.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';

class UserPage extends StatefulWidget {
  final AudioHandler audioHandler;

  const UserPage({
    super.key,
    required this.audioHandler,
  });

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String _userName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final request = ModelQueries.list(
        Users.classType,
        where: Users.NAME.eq(user.username),
      );
      final response = await Amplify.API.query(request: request).response;

      if (response.data?.items != null && response.data!.items.isNotEmpty) {
        final userProfile = response.data!.items.first;
        setState(() {
          _userName = userProfile?.name ?? 'User';
        });
      }
    } catch (e) {
      safePrint('Error fetching user profile: $e');
    }
  }

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
          Text(
            _userName,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PlaylistPage(audioHandler: widget.audioHandler),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Listening History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
          const Divider(),
          // Add Sign Out ListTile
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xffa91d3a)),
            title: const Text('Sign Out',
                style: TextStyle(
                    color: Color(0xffa91d3a), fontWeight: FontWeight.bold)),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFF151515),
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xffFDFDFD))),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: const Text('Sign Out',
                            style: TextStyle(
                              color: Color(0xffa91d3a),
                              fontWeight: FontWeight.bold,
                            )),
                        onPressed: () async {
                          try {
                            await Amplify.Auth.signOut();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => const MyApp()),
                              (route) => false,
                            );
                          } catch (e) {
                            safePrint('Error signing out: $e');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Error signing out')),
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
