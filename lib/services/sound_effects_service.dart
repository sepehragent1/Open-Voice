import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundEffectsService {
  final AudioPlayer _player = AudioPlayer();
  Future<void> _playQueue = Future<void>.value();

  Future<void> play(String sound) {
    if (!const {'mute', 'unmute', 'join', 'leave'}.contains(sound)) {
      return Future<void>.error(
        ArgumentError.value(sound, 'sound', 'Unsupported sound effect'),
      );
    }
    _playQueue = _playQueue.then((_) => _play(sound));
    return _playQueue;
  }

  Future<void> _play(String sound) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$sound.mp3'));
    } catch (error, stackTrace) {
      debugPrint('AudioPlayer failed to play "$sound": $error\n$stackTrace');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice audio',
          context: ErrorDescription('while playing the $sound sound effect'),
        ),
      );
    }
  }

  Future<void> dispose() => _player.dispose();
}
