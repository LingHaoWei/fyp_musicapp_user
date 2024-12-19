import 'package:flutter/services.dart';
import 'audio_handler.dart';

class GoogleAssistantHandler {
  static const platform =
      MethodChannel('com.example.your_app/google_assistant');
  final AudioHandler audioHandler;

  GoogleAssistantHandler({required this.audioHandler}) {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'playMedia':
          await audioHandler.play();
          break;
        case 'pauseMedia':
          await audioHandler.pause();
          break;
        case 'nextTrack':
          // Implement next track logic
          break;
        case 'previousTrack':
          // Implement previous track logic
          break;
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: 'Method ${call.method} not implemented',
          );
      }
    });
  }
}
