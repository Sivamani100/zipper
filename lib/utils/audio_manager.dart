import 'audio_manager_stub.dart'
    if (dart.library.html) 'audio_manager_web.dart'
    if (dart.library.io) 'audio_manager_native.dart';

abstract class AudioManager {
  static void playClick() => AudioManagerImpl.playClick();
  static void playSuccess() => AudioManagerImpl.playSuccess();
}
