import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A class to manage user-configurable settings like sound and haptics.
class SettingsManager with ChangeNotifier {
  static const _soundKey = 'sound_enabled';
  static const _hapticsKey = 'haptics_enabled';
  static const _instantErrorKey = 'instant_error_checking_enabled';

  bool _isSoundEnabled = true;
  bool _isHapticsEnabled = true;
  bool _instantErrorChecking = true;

  bool get isSoundEnabled => _isSoundEnabled;
  bool get isHapticsEnabled => _isHapticsEnabled;
  bool get instantErrorChecking => _instantErrorChecking;

  SettingsManager() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool(_soundKey) ?? true;
    _isHapticsEnabled = prefs.getBool(_hapticsKey) ?? true;
    _instantErrorChecking = prefs.getBool(_instantErrorKey) ?? true;
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    _isSoundEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    _isHapticsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, value);
  }

  Future<void> setInstantErrorChecking(bool value) async {
    _instantErrorChecking = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_instantErrorKey, value);
  }
}
