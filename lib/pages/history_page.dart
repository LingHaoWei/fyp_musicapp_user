import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import '../models/ModelProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fyp_musicapp_aws/services/audio_handler.dart';

class HistoryPage extends StatefulWidget {
  final AudioHandler audioHandler;

  const HistoryPage({
    super.key,
    required this.audioHandler,
  });

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
                          leading: FutureBuilder<String>(
                            future: widget.audioHandler
                                .getAlbumArtUrl(song.album ?? 'logo'),
                            builder: (context, snapshot) {
                              return Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: !snapshot.hasData
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Center(
                                            child: CircularProgressIndicator()),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: snapshot.data!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                            color: Colors.grey[800],
                                            child: const Center(
                                                child:
                                                    CircularProgressIndicator()),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            color: Colors.grey[800],
                                            child: const Icon(Icons.music_note),
                                          ),
                                        ),
                                      ),
                              );
                            },
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
                                          onTap: () async {
                                            final navigator =
                                                Navigator.of(context);
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            // Close the bottom sheet first
                                            navigator.pop();

                                            // Remove the history item
                                            if (history != null) {
                                              try {
                                                final request =
                                                    ModelMutations.delete(
                                                        history);
                                                await Amplify.API
                                                    .mutate(request: request)
                                                    .response;

                                                // Refresh the history list
                                                await _fetchHistory();

                                                if (mounted) {
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'Removed from history',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          )),
                                                      backgroundColor:
                                                          Color(0xFF303030),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                safePrint(
                                                    'Error removing history item: $e');
                                                if (mounted) {
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'Error removing from history',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          )),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
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
