import 'dart:async';
import 'dart:collection';
import 'package:just_audio/just_audio.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:rxdart/rxdart.dart';

class AudioHandler {
  final AudioPlayer player;
  Songs? _currentSong;
  final _urlCache = HashMap<String, String>();
  final _preloadQueue = Queue<Songs>();

  final _currentSongSubject = BehaviorSubject<Songs?>();
  final _playingStateSubject = BehaviorSubject<bool>.seeded(false);
  final _durationSubject = BehaviorSubject<Duration>();
  final _positionSubject = BehaviorSubject<Duration>();
  final _volumeSubject = BehaviorSubject<double>.seeded(1.0);
  final _loopModeSubject = BehaviorSubject<LoopMode>.seeded(LoopMode.off);
  final _shuffleModeSubject = BehaviorSubject<bool>.seeded(false);

  AudioHandler(this.player) {
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
    player.playerStateStream.listen((state) {
      _updatePlayingState(state.playing);

      if (state.processingState == ProcessingState.completed) {
        if (_loopModeSubject.value == LoopMode.one) {
          player.seek(Duration.zero);
          player.play();
        } else {
          _currentSong = null;
          _currentSongSubject.add(null);
          _updatePlayingState(false);
        }
      }
    });

    player.playingStream.listen(_updatePlayingState);
    player.durationStream
        .listen((duration) => _durationSubject.add(duration ?? Duration.zero));
    player.positionStream.listen((position) => _positionSubject.add(position));
    player.volumeStream.listen((volume) => _volumeSubject.add(volume));
    player.loopModeStream.listen((mode) => _loopModeSubject.add(mode));
    player.shuffleModeEnabledStream
        .listen((enabled) => _shuffleModeSubject.add(enabled));

    player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        _updatePlayingState(false);
      },
    );
  }

  void _updatePlayingState(bool playing) {
    _playingStateSubject.add(playing);
  }

  // Streams
  Stream<PlayerState> get playbackState => player.playerStateStream;
  Stream<Duration?> get durationStream => _durationSubject.stream;
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Songs?> get currentSongStream => _currentSongSubject.stream;
  Stream<bool> get playingStream => _playingStateSubject.stream;
  Stream<double> get volumeStream => _volumeSubject.stream;
  Stream<LoopMode> get loopModeStream => _loopModeSubject.stream;
  Stream<bool> get shuffleModeStream => _shuffleModeSubject.stream;

  // Properties
  Songs? get currentSong => _currentSong;
  bool get isPlaying => _playingStateSubject.value;
  double get volume => _volumeSubject.value;
  LoopMode get loopMode => _loopModeSubject.value;
  bool get isShuffleModeEnabled => _shuffleModeSubject.value;

  Future<void> playSong(Songs song, List<Songs> queue) async {
    try {
      _currentSong = song;
      _currentSongSubject.add(song);
      _preloadQueue.clear();
      _preloadQueue.addAll(queue);

      final url = await _getUrl(song);
      await player.setUrl(url);
      await player.play();

      // Preload next songs
      _preloadNextSongs();
    } catch (e) {
      _updatePlayingState(false);
      rethrow;
    }
  }

  Future<String> _getUrl(Songs song) async {
    final cacheKey = '${song.id}_${song.fileType}_${song.title}';
    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey]!;
    }

    final result = await Amplify.Storage.getUrl(
      path: StoragePath.fromString(
        'public/songs/${song.fileType}/${song.title}',
      ),
      options: const StorageGetUrlOptions(),
    ).result;

    final url = result.url.toString();
    _urlCache[cacheKey] = url;
    return url;
  }

  Future<void> _preloadNextSongs() async {
    for (var i = 0; i < 2 && _preloadQueue.isNotEmpty; i++) {
      final nextSong = _preloadQueue.removeFirst();
      await _getUrl(nextSong); // Cache URL
    }
  }

  Future<void> play() async {
    try {
      await player.play();
    } catch (e) {
      _updatePlayingState(false);
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await player.pause();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await player.stop();
      _currentSong = null;
      _currentSongSubject.add(null);
      _updatePlayingState(false);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> seekTo(Duration position) => player.seek(position);

  void clearCache() {
    _urlCache.clear();
    _preloadQueue.clear();
  }

  void dispose() {
    _currentSongSubject.close();
    _playingStateSubject.close();
    _durationSubject.close();
    _positionSubject.close();
    _volumeSubject.close();
    _loopModeSubject.close();
    _shuffleModeSubject.close();
    clearCache();
  }

  // Control methods
  Future<void> setVolume(double volume) async {
    await player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await player.setLoopMode(mode);
  }

  Future<void> setShuffleMode(bool enabled) async {
    await player.setShuffleModeEnabled(enabled);
  }
}
