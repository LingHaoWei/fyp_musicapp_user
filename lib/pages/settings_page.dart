import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import '../models/Users.dart';
import 'home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = '';
  String _preferFileType = '';
  Users? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final request = ModelQueries.list(
        Users.classType,
        where: Users.NAME.eq(user.username),
      );
      final response = await Amplify.API.query(request: request).response;

      if (response.data?.items != null && response.data!.items.isNotEmpty) {
        _currentUser = response.data!.items.first;
        setState(() {
          _userName = _currentUser?.name ?? '';
          _preferFileType = _currentUser?.preferFileType ?? 'mp3';
        });
      }
    } catch (e) {
      safePrint('Error loading settings: $e');
    }
  }

  Future<void> _updatePreferFileType(String newType) async {
    try {
      if (_currentUser == null) return;

      final updatedUser = _currentUser!.copyWith(
        preferFileType: newType,
      );

      final request = ModelMutations.update(updatedUser);
      final response = await Amplify.API.mutate(request: request).response;

      if (response.data != null) {
        setState(() {
          _preferFileType = newType;
        });
        if (!mounted) return;

        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Dialog(
              backgroundColor: Color(0xFF202020),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xffa91d3a),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Restarting app...',
                      style: TextStyle(
                        color: Color(0xFFFDFDFD),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        try {
          // Add a small delay to show the loading dialog
          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) return;

          // Navigate to a fresh instance of HomePage
          await Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const HomePage(),
              settings: const RouteSettings(name: '/home'),
            ),
            (route) => false,
          );
        } catch (e) {
          safePrint('Error during navigation: $e');
          if (!mounted) return;
          Navigator.of(context).pop(); // Remove loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error restarting app',
                style: TextStyle(color: Color(0xFFFDFDFD)),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      safePrint('Error updating preferences: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to update preferences',
            style: TextStyle(color: Color(0xFFFDFDFD)),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFileTypeDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          title: const Text('Select Preferred File Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('MP3'),
                leading: Radio<String>(
                  value: 'mp3',
                  groupValue: _preferFileType,
                  onChanged: (String? value) {
                    Navigator.pop(context);
                    if (value != null) _updatePreferFileType(value);
                  },
                ),
              ),
              ListTile(
                title: const Text('FLAC'),
                leading: Radio<String>(
                  value: 'flac',
                  groupValue: _preferFileType,
                  onChanged: (String? value) {
                    Navigator.pop(context);
                    if (value != null) _updatePreferFileType(value);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'ACCOUNT',
                  style: TextStyle(
                    color: Color(0xFFFDFDFD),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Card(
                color: const Color(0xFF151515),
                child: ListTile(
                  title: const Text(
                    'Username',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_userName),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202020),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFFFDFDFD)),
                  ),
                ),
              ),

              // Playback Section
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'PLAYBACK',
                  style: TextStyle(
                    color: Color(0xFFFDFDFD),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Card(
                color: const Color(0xFF151515),
                child: ListTile(
                  title: const Text('Preferred File Type'),
                  subtitle: Text(_preferFileType.toUpperCase()),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202020),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.audio_file, color: Color(0xffa91d3a)),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showFileTypeDialog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
