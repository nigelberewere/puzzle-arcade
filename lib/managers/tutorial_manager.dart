import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the completion status of tutorials for all games.
///
/// This class uses SharedPreferences to persist which tutorials the user
/// has already seen, ensuring they only appear once per game.
class TutorialManager with ChangeNotifier {
  // A prefix for keys in SharedPreferences to avoid conflicts.
  static const String _tutorialKeyPrefix = 'tutorial_completed_';

  // A set containing the names of games for which the tutorial is completed.
  final Set<String> _completedTutorials = {};

  TutorialManager() {
    _loadAllTutorialStatuses();
  }

  /// Loads the completion status for all tutorials from SharedPreferences.
  Future<void> _loadAllTutorialStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    // Find all keys that match our tutorial prefix.
    final tutorialKeys = prefs.getKeys().where((key) => key.startsWith(_tutorialKeyPrefix));
    for (final key in tutorialKeys) {
      if (prefs.getBool(key) ?? false) {
        // Extract the game name from the key and add it to the completed set.
        _completedTutorials.add(key.substring(_tutorialKeyPrefix.length));
      }
    }
    notifyListeners();
  }

  /// Checks if the tutorial for a specific game has been completed.
  ///
  /// [gameName] The name of the game (e.g., 'Sudoku', 'KenKen').
  bool isTutorialCompleted(String gameName) {
    return _completedTutorials.contains(gameName);
  }

  /// Marks the tutorial for a specific game as completed and saves it.
  ///
  /// [gameName] The name of the game to mark as completed.
  Future<void> completeTutorial(String gameName) async {
    if (_completedTutorials.contains(gameName)) return;

    _completedTutorials.add(gameName);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // Save the completion status to persistent storage.
    await prefs.setBool('$_tutorialKeyPrefix$gameName', true);
  }
}

