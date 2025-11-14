import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models.dart';

class GameStats {
  int puzzlesSolved;
  int totalTime; // in milliseconds
  int bestTime; // in milliseconds

  GameStats({this.puzzlesSolved = 0, this.totalTime = 0, this.bestTime = 0});

  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      puzzlesSolved: json['puzzlesSolved'] as int? ?? 0,
      totalTime: json['totalTime'] as int? ?? 0,
      bestTime: json['bestTime'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'puzzlesSolved': puzzlesSolved,
    'totalTime': totalTime,
    'bestTime': bestTime,
  };
}


/// A class to manage saving and loading the game state for the puzzles.
class GameStateManager {
  static const _sudokuStateKey = 'sudoku_game_state';
  static const _kenkenStateKey = 'kenken_game_state';
  static const _hitoriStateKey = 'hitori_game_state';
  static const _kakuroStateKey = 'kakuro_game_state';
  static const _slitherlinkStateKey = 'slitherlink_game_state';
  static const _futoshiStateKey = 'futoshi_game_state';
  static const _gameStatsKey = 'game_statistics';
  static const _dailyChallengeKey = 'daily_challenge';
  static const _firstTimeKey = 'is_first_time';
  static const _firstTimeGameKey = 'first_time_game_';


  // --- First Time Check ---
  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstTimeKey) ?? true;
  }

  static Future<void> setFirstTime(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstTimeKey, value);
  }
  
  // --- First Time Per Game Check ---
  static Future<bool> isFirstTimeForGame(String gameName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_firstTimeGameKey${gameName.toLowerCase()}') ?? true;
  }

  static Future<void> setFirstTimeForGame(String gameName, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_firstTimeGameKey${gameName.toLowerCase()}', value);
  }


  // --- Sudoku State Management ---
  static Future<void> saveSudokuState({
    required List<List<int>> initialGrid,
    required List<List<dynamic>> userGrid,
    required SudokuDifficulty difficulty,
    required int elapsedMilliseconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert sets to lists for JSON serialization
    final serializableGrid = userGrid.map((row) {
      return row.map((cell) => cell is Set ? cell.toList() : cell).toList();
    }).toList();
    final state = {
      'initialGrid': initialGrid,
      'userGrid': serializableGrid,
      'difficulty': difficulty.index,
      'elapsedMilliseconds': elapsedMilliseconds,
    };
    await prefs.setString(_sudokuStateKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadSudokuState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_sudokuStateKey);
    if (savedState != null) {
      try {
        final state = jsonDecode(savedState) as Map<String, dynamic>;
        state['initialGrid'] = (state['initialGrid'] as List)
            .map((row) => (row as List).cast<int>())
            .toList();
        // Convert lists back to sets for notes
        state['userGrid'] = (state['userGrid'] as List).map((row) {
          return (row as List).map((cell) {
            return cell is List ? cell.cast<int>().toSet() : cell;
          }).toList();
        }).toList();
        state['difficulty'] = SudokuDifficulty.values[state['difficulty'] as int];
        return state;
      } catch (e) {
        await clearSudokuState();
        return null;
      }
    }
    return null;
  }

  static Future<void> clearSudokuState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sudokuStateKey);
  }

  // --- KenKen State Management ---
  static Future<void> saveKenKenState({
    required KenKenPuzzle puzzle,
    required List<List<int>> userGrid,
    required int elapsedMilliseconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'puzzle': puzzle.toJson(),
      'userGrid': userGrid,
      'elapsedMilliseconds': elapsedMilliseconds,
    };
    await prefs.setString(_kenkenStateKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadKenKenState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_kenkenStateKey);
    if (savedState != null) {
      try {
        final state = jsonDecode(savedState);
        if (state is Map<String, dynamic> && state.containsKey('puzzle')) {
      state['puzzle'] = KenKenPuzzle.fromJson(state['puzzle']);
          state['userGrid'] = (state['userGrid'] as List)
              .map((row) => (row as List).map((cell) => cell as int).toList())
              .toList();
          return state;
        }
      } catch (e) {
        await clearKenKenState();
        return null;
      }
    }
    return null;
  }

  static Future<void> clearKenKenState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kenkenStateKey);
  }

  // --- Hitori State Management ---
  static Future<void> saveHitoriState({
    required HitoriPuzzle puzzle,
    required List<List<HitoriCellState>> userState,
    required int elapsedMilliseconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'puzzle': puzzle.toJson(),
      'userState': userState.map((row) => row.map((s) => s.index).toList()).toList(),
      'elapsedMilliseconds': elapsedMilliseconds,
    };
    await prefs.setString(_hitoriStateKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadHitoriState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_hitoriStateKey);
    if (savedState != null) {
      try {
        final state = jsonDecode(savedState);
        if (state is Map<String, dynamic> && state.containsKey('puzzle')) {
          state['puzzle'] = HitoriPuzzle.fromJson(state['puzzle']);
          state['userState'] = (state['userState'] as List)
              .map((row) => (row as List).map((i) => HitoriCellState.values[i as int]).toList())
              .toList();
          return state;
        }
      } catch (e) {
        await clearHitoriState();
        return null;
      }
    }
    return null;
  }

  static Future<void> clearHitoriState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hitoriStateKey);
  }

    // --- Kakuro State Management ---
  static Future<void> saveKakuroState({
    required KakuroPuzzle puzzle,
    required List<List<int>> userGrid,
    required int elapsedMilliseconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'puzzle': puzzle.toJson(),
      'userGrid': userGrid,
      'elapsedMilliseconds': elapsedMilliseconds,
    };
    await prefs.setString(_kakuroStateKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadKakuroState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_kakuroStateKey);
    if (savedState != null) {
      try {
        final state = jsonDecode(savedState);
        if (state is Map<String, dynamic> && state.containsKey('puzzle')) {
          state['puzzle'] = KakuroPuzzle.fromJson(state['puzzle']);
          state['userGrid'] = (state['userGrid'] as List)
              .map((row) => (row as List).map((cell) => cell as int).toList())
              .toList();
          return state;
        }
      } catch (e) {
        await clearKakuroState();
        return null;
      }
    }
    return null;
  }

  static Future<void> clearKakuroState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kakuroStateKey);
  }
  // --- Slitherlink State Management ---
  static Future<void> saveSlitherlinkState({
    required SlitherlinkPuzzle puzzle,
    required List<List<LineState>> hLines,
    required List<List<LineState>> vLines,
    required int elapsedMilliseconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'puzzle': puzzle.toJson(),
      'hLines': hLines.map((row) => row.map((s) => s.index).toList()).toList(),
      'vLines': vLines.map((row) => row.map((s) => s.index).toList()).toList(),
      'elapsedMilliseconds': elapsedMilliseconds,
    };
    await prefs.setString(_slitherlinkStateKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadSlitherlinkState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_slitherlinkStateKey);
    if (savedState != null) {
      try {
        final state = jsonDecode(savedState);
        if (state is Map<String, dynamic> && state.containsKey('puzzle')) {
          state['puzzle'] = SlitherlinkPuzzle.fromJson(state['puzzle']);
          state['hLines'] = (state['hLines'] as List)
              .map((row) => (row as List).map((v) => LineState.values[v as int]).toList())
              .toList();
          state['vLines'] = (state['vLines'] as List)
              .map((row) => (row as List).map((v) => LineState.values[v as int]).toList())
              .toList();
          return state;
        }
      } catch (e) {
        await clearSlitherlinkState();
        return null;
      }
    }
    return null;
  }

  static Future<void> clearSlitherlinkState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_slitherlinkStateKey);
  }

  // --- Futoshi State Management ---
  static Future<void> saveFutoshiState({
    required FutoshiPuzzle puzzle,
    required List<List<int>> userGrid,
    required FutoshiDifficulty difficulty,
    required int elapsedMilliseconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'puzzle': puzzle.toJson(),
      'userGrid': userGrid,
      'difficulty': difficulty.index,
      'elapsedMilliseconds': elapsedMilliseconds,
    };
    await prefs.setString(_futoshiStateKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadFutoshiState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_futoshiStateKey);
    if (savedState != null) {
      try {
        final state = jsonDecode(savedState);
        if (state is Map<String, dynamic> && state.containsKey('puzzle')) {
          state['puzzle'] = FutoshiPuzzle.fromJson(state['puzzle']);
          state['userGrid'] = (state['userGrid'] as List)
              .map((row) => (row as List).map((cell) => cell as int).toList())
              .toList();
          state['difficulty'] = FutoshiDifficulty.values[state['difficulty'] as int];
          return state;
        }
      } catch (e) {
        await clearFutoshiState();
        return null;
      }
    }
    return null;
  }

  static Future<void> clearFutoshiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_futoshiStateKey);
  }

  // --- Game Statistics Management ---

  static Future<Map<String, GameStats>> loadGameStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsString = prefs.getString(_gameStatsKey);
    if (statsString == null) return {};

    final Map<String, dynamic> statsJson = jsonDecode(statsString);
    return statsJson.map((key, value) => MapEntry(key, GameStats.fromJson(value)));
  }

  static Future<void> saveGameStats(Map<String, GameStats> stats) async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = stats.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString(_gameStatsKey, jsonEncode(statsJson));
  }

  // FIX: Added optional 'difficulty' parameter to match the function calls.
  static Future<void> updateStats({required String gameName, required int timeTaken, String? difficulty}) async {
    final stats = await loadGameStats();
    final gameStats = stats[gameName] ?? GameStats();

    gameStats.puzzlesSolved++;
    gameStats.totalTime += timeTaken;
    if (gameStats.bestTime == 0 || timeTaken < gameStats.bestTime) {
      gameStats.bestTime = timeTaken;
    }
    
    // Note: The difficulty is now accepted but not yet stored.
    // You can add logic here later to store best times per difficulty.

    stats[gameName] = gameStats;
    await saveGameStats(stats);
  }

  // --- Daily Challenge Management ---

  static Future<void> markDailyAsCompleted(int seed) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> completed = prefs.getStringList(_dailyChallengeKey) ?? [];
    if (!completed.contains(seed.toString())) {
      completed.add(seed.toString());
      await prefs.setStringList(_dailyChallengeKey, completed);
    }
  }

  static Future<bool> isDailyCompleted(int seed) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> completed = prefs.getStringList(_dailyChallengeKey) ?? [];
    return completed.contains(seed.toString());
  }
}
