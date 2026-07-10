import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioManagerImpl {
  static void playClick() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('zip_sound_effects') ?? true;
      if (!soundEnabled) return;

      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  static void playSuccess() {
    // success sound fallback or system alert on native if desired
  }
}
