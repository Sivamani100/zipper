import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AudioManagerImpl {
  static final AudioPlayer _player = AudioPlayer();

  static void _playNativeSound(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('zip_sound_effects') ?? true;
      if (!soundEnabled) return;

      // Play sound using audioplayers
      await _player.play(UrlSource(url));
    } catch (_) {
      // Fallback to system click if remote url fails or offline
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void playClick() {
    _playNativeSound('https://assets.mixkit.co/sfx/preview/mixkit-button-press-and-click-1262.mp3');
  }

  static void playSuccess() {
    _playNativeSound('https://assets.mixkit.co/sfx/preview/mixkit-game-level-completed-2059.mp3');
  }
}
