import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AudioManagerImpl {
  static final AudioPlayer _player = AudioPlayer();

  static void _playNativeSound(String assetPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('zip_sound_effects') ?? true;
      if (!soundEnabled) return;

      // Play local sound from assets bundle
      await _player.play(AssetSource(assetPath));
    } catch (_) {
      // Fallback to system click if any loading issue occurs
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void playClick() {
    // Click sound disabled as per user request
  }

  static void playSuccess() {
    _playNativeSound('sounds/success.mp3');
  }
}
