import 'package:rxdart/rxdart.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';

class AppState {
  // Singleton instance
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // State controllers
  final _songsCache = <String, List<Songs>>{};
  final _playlistsSubject = BehaviorSubject<List<Playlists>>();
  final _recentSongsSubject = BehaviorSubject<List<Songs>>();
  final _searchResultsSubject = BehaviorSubject<List<Songs>>();
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);

  // Streams
  Stream<List<Playlists>> get playlists => _playlistsSubject.stream;
  Stream<List<Songs>> get recentSongs => _recentSongsSubject.stream;
  Stream<List<Songs>> get searchResults => _searchResultsSubject.stream;
  Stream<bool> get isLoading => _loadingSubject.stream;

  // Cache management
  Future<List<Songs>> getSongsWithCache(String query) async {
    if (_songsCache.containsKey(query)) {
      return _songsCache[query]!;
    }

    _loadingSubject.add(true);
    try {
      final request = ModelQueries.list(
        Songs.classType,
        where: Songs.TITLE
            .contains(query)
            .or(Songs.ARTIST.contains(query))
            .or(Songs.ALBUM.contains(query)),
      );

      final response = await Amplify.API.query(request: request).response;
      final items = response.data?.items.whereType<Songs>().toList() ?? [];

      _songsCache[query] = items;
      _searchResultsSubject.add(items);
      return items;
    } catch (e) {
      safePrint('Error fetching songs: $e');
      return [];
    } finally {
      _loadingSubject.add(false);
    }
  }

  Future<void> refreshPlaylists() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final request = ModelQueries.list(
        Playlists.classType,
        where: Playlists.USERID.eq(user.userId),
      );

      final response = await Amplify.API.query(request: request).response;
      final items = response.data?.items.whereType<Playlists>().toList() ?? [];

      _playlistsSubject.add(items);
    } catch (e) {
      safePrint('Error fetching playlists: $e');
    }
  }

  Future<void> refreshRecentSongs() async {
    try {
      final request = ModelQueries.list(
        Songs.classType,
        limit: 10,
      );

      final response = await Amplify.API.query(request: request).response;
      final items = response.data?.items.whereType<Songs>().toList() ?? [];

      _recentSongsSubject.add(items);
    } catch (e) {
      safePrint('Error fetching recent songs: $e');
    }
  }

  void clearCache() {
    _songsCache.clear();
  }

  void dispose() {
    _playlistsSubject.close();
    _recentSongsSubject.close();
    _searchResultsSubject.close();
    _loadingSubject.close();
  }
}
