import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';

class AudioManagerImpl {
  static void _playWebSound(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('zip_sound_effects') ?? true;
      if (!soundEnabled) return;

      final audio = html.AudioElement()..src = url;
      audio.play();
    } catch (e) {
      // Browser autoplay policy might block audio before first interaction, fail silently
    }
  }

  static void playClick() {
    _playWebSound('https://assets.mixkit.co/sfx/preview/mixkit-button-press-and-click-1262.mp3');
  }

  static void playSuccess() {
    _playWebSound('https://assets.mixkit.co/sfx/preview/mixkit-game-level-completed-2059.mp3');
  }
}
