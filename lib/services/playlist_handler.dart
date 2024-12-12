import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';

class PlaylistHandler {
  final _playlistsController = StreamController<List<Playlists>>.broadcast();
  Stream<List<Playlists>> get playlistsStream => _playlistsController.stream;
  List<Playlists> _currentPlaylists = [];

  Future<void> refreshPlaylists() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final request = ModelQueries.list(
        Playlists.classType,
        where: Playlists.USERID.eq(user.userId),
      );

      final response = await Amplify.API.query(request: request).response;
      final items = response.data?.items.whereType<Playlists>().toList() ?? [];

      _currentPlaylists = items;
      _playlistsController.add(_currentPlaylists);
    } catch (e) {
      safePrint('Error fetching playlists: $e');
    }
  }

  List<Playlists> get currentPlaylists => _currentPlaylists;

  void dispose() {
    _playlistsController.close();
  }
}
