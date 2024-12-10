import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:fyp_musicapp_aws/models/ModelProvider.dart';

class AudioHandler {
  final AudioPlayer player;
  Songs? _currentSong;
  bool _isPlaying = false;
  final _currentSongController = StreamController<Songs?>.broadcast();
  final _playingStateController = StreamController<bool>.broadcast();

  AudioHandler(this.player) {
    // Listen to both playerState and playing state changes
    player.playerStateStream.listen((state) {
      _updatePlayingState(state.playing);

      if (state.processingState == ProcessingState.completed) {
        _currentSong = null;
        _currentSongController.add(null);
        _updatePlayingState(false);
      }
    });

    // Additional listener for playing state changes
    player.playingStream.listen((playing) {
      _updatePlayingState(playing);
    });

    // Listen to errors
    player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      _updatePlayingState(false);
    });
  }

  void _updatePlayingState(bool playing) {
    if (_isPlaying != playing) {
      _isPlaying = playing;
      _playingStateController.add(_isPlaying);
    }
  }

  Stream<PlayerState> get playbackState => player.playerStateStream;
  Stream<Duration?> get durationStream => player.durationStream;
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Songs?> get currentSongStream => _currentSongController.stream;
  Stream<bool> get playingStream => _playingStateController.stream;
  Songs? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;

  Future<void> playSong(Songs song, String url) async {
    try {
      if (_currentSong?.id == song.id) {
        if (_isPlaying) {
          await pause();
        } else {
          await play();
        }
        return;
      }

      _currentSong = song;
      _currentSongController.add(song);

      await player.setUrl(url);
      await player.play();
    } catch (e) {
      _updatePlayingState(false);
      rethrow;
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
      _currentSongController.add(null);
      _updatePlayingState(false);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> seekTo(Duration position) => player.seek(position);

  void dispose() {
    _currentSongController.close();
    _playingStateController.close();
  }
}
