import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import '../models/ModelProvider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<History?> _historyItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();

      // Query history items for current user
      final request = ModelQueries.list(
        History.classType,
        where: History.USERID.eq(user.userId),
      );

      final response = await Amplify.API.query(request: request).response;
      final items = response.data?.items;

      if (mounted) {
        setState(() {
          // Sort items by updatedAt before setting state
          _historyItems = (items ?? [])
            ..sort((a, b) {
              final aDate = a?.updatedAt?.getDateTimeInUtc();
              final bDate = b?.updatedAt?.getDateTimeInUtc();
              if (aDate == null || bDate == null) return 0;
              return bDate.compareTo(aDate); // Most recent first
            });
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error fetching history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Songs?> _fetchSongDetails(String songId) async {
    try {
      final request = ModelQueries.get(
        Songs.classType,
        SongsModelIdentifier(id: songId),
      );
      final response = await Amplify.API.query(request: request).response;
      return response.data;
    } catch (e) {
      safePrint('Error fetching song details: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening History'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyItems.isEmpty
              ? const Center(child: Text('No listening history yet'))
              : ListView.builder(
                  itemCount: _historyItems.length,
                  itemBuilder: (context, index) {
                    final history = _historyItems[index];
                    return FutureBuilder<Songs?>(
                      future: _fetchSongDetails(history?.songID ?? ''),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text('Loading...'),
                          );
                        }

                        final song = snapshot.data;
                        if (song == null) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: AssetImage(
                                    'images/${song.album ?? 'logo'}.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(song.title ?? 'Unknown Title'),
                          subtitle: Text(song.artist ?? 'Unknown Artist'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: const Color(0xFF151515),
                                    builder: (context) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.delete),
                                          title:
                                              const Text('Remove from History'),
                                          onTap: () {
                                            // Implement delete functionality
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
