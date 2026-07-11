import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';

class AudioManagerImpl {
  static void _playWebSound(String assetPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('zip_sound_effects') ?? true;
      if (!soundEnabled) return;

      // In Flutter Web, assets are served at 'assets/assets/sounds/...'
      final audio = html.AudioElement()..src = 'assets/assets/' + assetPath;
      audio.play();
    } catch (e) {
      // Browser autoplay policy might block audio before first interaction, fail silently
    }
  }

  static void playClick() {
    // Click sound disabled as per user request
  }

  static void playSuccess() {
    _playWebSound('sounds/success.mp3');
  }
}
