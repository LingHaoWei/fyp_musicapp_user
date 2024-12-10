import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class LifecycleEventHandler extends WidgetsBindingObserver {
  final AudioPlayer audioPlayer;

  LifecycleEventHandler(this.audioPlayer);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      audioPlayer.stop();
    }
  }
}
