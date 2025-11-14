import 'dart:async';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../models/achievement.dart';
import 'firebase_service.dart';

class AchievementsService with ChangeNotifier {
  final FirebaseService _firebaseService;
  late final StreamSubscription _authSubscription;

  AchievementsService(this._firebaseService) {
    _loadAchievements();
    // Listen for authentication changes to reload achievements for the new user
    _authSubscription = _firebaseService.authStateChanges().listen((_) {
      _loadAchievements();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // --- State ---
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  final Map<AchievementId, Achievement> _unlockedAchievements = {};
  List<Achievement> get allAchievements {
    // Return a list where the user's unlocked status is correctly reflected
    return _achievementDefinitions.map((def) {
      if (_unlockedAchievements.containsKey(def.id)) {
        return _unlockedAchievements[def.id]!
          ..isUnlocked = true;
      }
      return def..isUnlocked = false; // Ensure it's marked as locked
    }).toList();
  }

  // --- Public Methods ---
  Future<void> _loadAchievements() async {
    _isLoading = true;
    notifyListeners();
    final unlockedIds = await _firebaseService.getUnlockedAchievements();
    _unlockedAchievements.clear();
    for (var idString in unlockedIds) {
      final achievementId = AchievementId.values.firstWhereOrNull((e) => e.name == idString);
      if (achievementId != null) {
        final achievement = _achievementDefinitions.firstWhere((def) => def.id == achievementId);
        _unlockedAchievements[achievementId] = achievement..isUnlocked = true;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkAndUnlockAchievement(AchievementId id, {dynamic value}) async {
    if (_unlockedAchievements.containsKey(id)) return; // Already unlocked

    final achievement = _achievementDefinitions.firstWhere((def) => def.id == id);
    bool shouldUnlock = false;

    // This is where you would put more complex logic if needed
    // For now, we assume if the check is called, the condition is met.
    shouldUnlock = true;

    if (shouldUnlock) {
      await _firebaseService.unlockAchievement(id);
      _unlockedAchievements[id] = achievement..isUnlocked = true;
      notifyListeners();
      // Optional: Show a snackbar or other notification to the user
    }
  }

  // --- All Achievement Definitions ---
  static final List<Achievement> _achievementDefinitions = [
    // Sudoku
    Achievement(id: AchievementId.sudokuSolved1, game: 'Sudoku', title: 'Sudoku Novice', description: 'Solve your first Sudoku puzzle.', icon: Icons.grid_3x3),
    Achievement(id: AchievementId.sudokuSolved10, game: 'Sudoku', title: 'Sudoku Apprentice', description: 'Solve 10 Sudoku puzzles.', icon: Icons.grid_3x3),
    Achievement(id: AchievementId.sudokuHard, game: 'Sudoku', title: 'Sudoku Master', description: 'Solve a Sudoku puzzle on hard difficulty.', icon: Icons.grid_3x3),
    // KenKen
    Achievement(id: AchievementId.kenkenSolved1, game: 'KenKen', title: 'KenKen Beginner', description: 'Solve your first KenKen puzzle.', icon: Icons.calculate),
    Achievement(id: AchievementId.kenkenSolved10, game: 'KenKen', title: 'KenKen Enthusiast', description: 'Solve 10 KenKen puzzles.', icon: Icons.calculate),
    Achievement(id: AchievementId.kenkenHard, game: 'KenKen', title: 'KenKen Genius', description: 'Solve a KenKen puzzle on hard difficulty.', icon: Icons.calculate),
    // Hitori
    Achievement(id: AchievementId.hitoriSolved1, game: 'Hitori', title: 'Hitori Debut', description: 'Solve your first Hitori puzzle.', icon: Icons.hide_source),
    // Kakuro
    Achievement(id: AchievementId.kakuroSolved1, game: 'Kakuro', title: 'Kakuro Starter', description: 'Solve your first Kakuro puzzle.', icon: Icons.border_all_rounded),
    // Slitherlink
    Achievement(id: AchievementId.slitherlinkSolved1, game: 'Slitherlink', title: 'First Loop', description: 'Solve your first Slitherlink puzzle.', icon: Icons.change_history),
    // Futoshi
    Achievement(id: AchievementId.futoshiSolved1, game: 'Futoshi', title: 'Futoshi First', description: 'Solve your first Futoshi puzzle.', icon: Icons.filter_list_alt),
    // Nonogram
    Achievement(id: AchievementId.nonogramSolved1, game: 'Nonogram', title: 'Picture Perfect Start', description: 'Solve your first Nonogram puzzle.', icon: Icons.grid_on),
    Achievement(id: AchievementId.nonogramMistakeFree, game: 'Nonogram', title: 'Flawless Victory', description: 'Solve a Nonogram puzzle with no mistakes.', icon: Icons.grid_on),
  ];
}

