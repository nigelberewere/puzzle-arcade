import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  indigo(Colors.indigo),
  teal(Colors.teal),
  crimson(Color(0xFFF44336)),
  forest(Colors.green),
  orchid(Colors.purple),
  ocean(Colors.blue),
  sunset(Colors.orange),
  aurora(Colors.cyan);

  const AppTheme(this.seedColor);
  final Color seedColor;
}

class ThemeManager with ChangeNotifier {
  static const _themeModeKey = 'theme_mode';
  static const _themeColorKey = 'theme_color';

  ThemeMode _themeMode = ThemeMode.system;
  AppTheme _appTheme = AppTheme.indigo;

  ThemeMode get themeMode => _themeMode;
  AppTheme get appTheme => _appTheme;

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: _appTheme.seedColor,
    useMaterial3: true,
  );

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: _appTheme.seedColor,
    useMaterial3: true,
  );

  ThemeManager() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    final themeColorIndex = prefs.getInt(_themeColorKey) ?? AppTheme.indigo.index;

    _themeMode = ThemeMode.values[themeModeIndex];
    _appTheme = AppTheme.values[themeColorIndex];

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;
    _themeMode = themeMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, themeMode.index);
  }

  Future<void> setThemeColor(AppTheme appTheme) async {
    if (_appTheme == appTheme) return;
    _appTheme = appTheme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeColorKey, appTheme.index);
  }
}
