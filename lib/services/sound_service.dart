import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  SoundService._();
  static final instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> loadSounds() async {
    // This can be used to preload sounds if needed, but AssetSource handles it well.
  }

  Future<void> playSound(String assetName) async {
    // Don't play sounds on web as it can be jarring
    if (kIsWeb) return;

    // Check settings before playing a sound.
    final prefs = await SharedPreferences.getInstance();
    final isSoundEnabled = prefs.getBool('sound_enabled') ?? true;
    if (!isSoundEnabled) return;

    _player.play(AssetSource('audio/$assetName'));
  }

  void playCompleteSound() => playSound('complete.mp3');
  void playErrorSound() => playSound('error.mp3');
  void playWinSound() => playSound('win.mp3');

  void dispose() {
    _player.dispose();
  }
}
