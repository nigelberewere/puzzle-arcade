import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/sound_service.dart';

/// Enum representing the current status of the game.
enum GameStatus { playing, won, lost }

/// Manages the core state for a single puzzle session.
///
/// This includes tracking lives, mistakes, hints, and the game timer.
/// It uses `ChangeNotifier` to alert listening widgets about state updates.
class GameProvider with ChangeNotifier {
  // --- Private State Properties ---

  GameStatus _status = GameStatus.playing;
  int _lives = 3;
  int _mistakesMade = 0;
  int _hintsUsed = 0;
  final int _maxHints = 3;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsedTime = '00:00';
  int _savedMilliseconds = 0; // Used for resuming a game

  // --- Public Getters ---

  /// The current status of the game (playing, won, or lost).
  GameStatus get status => _status;
  
  /// The number of lives the player has remaining.
  int get lives => _lives;

  /// The total number of mistakes made in the current session.
  int get mistakesMade => _mistakesMade;

  /// The number of hints used in the current session.
  int get hintsUsed => _hintsUsed;

  /// The maximum number of hints available.
  int get maxHints => _maxHints;

  /// A formatted string representing the elapsed time (e.g., "01:23").
  String get elapsedTime => _elapsedTime;

  // --- Public Methods ---

  /// Starts or restarts the game, resetting all state variables.
  ///
  /// An optional [savedMilliseconds] can be provided to resume a timer
  /// from a previously saved state.
  void startGame({int? savedMilliseconds}) {
    _status = GameStatus.playing;
    _lives = 3;
    _mistakesMade = 0;
    _hintsUsed = 0;
    _savedMilliseconds = savedMilliseconds ?? 0;
    _startTimer();
    notifyListeners();
  }

  /// Starts the game timer, updating the elapsed time every second.
  void _startTimer() {
    _stopwatch.reset();
    _stopwatch.start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_stopwatch.isRunning) {
        _elapsedTime = _formatDuration(Duration(milliseconds: _stopwatch.elapsedMilliseconds + _savedMilliseconds));
        notifyListeners();
      }
    });
  }

  /// Stops the game timer.
  void stopTimer() {
    _stopwatch.stop();
    _timer?.cancel();
  }

  /// Returns the total elapsed milliseconds, including any saved time.
  int getElapsedMilliseconds() {
    return _stopwatch.elapsedMilliseconds + _savedMilliseconds;
  }

  /// Formats a [Duration] into a "mm:ss" string.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  /// Handles the logic when a player makes a mistake.
  ///
  /// Decrements lives, increments mistakes, and updates the game status to 'lost'
  /// if lives run out.
  void handleMistake() {
    SoundService.instance.playErrorSound();
    _mistakesMade++;
    _lives--;
    if (_lives <= 0) {
      _status = GameStatus.lost;
      stopTimer();
    }
    notifyListeners();
  }

  /// Sets the game status to 'won' and stops the timer.
  void winGame() {
    _status = GameStatus.won;
    stopTimer();
    SoundService.instance.playWinSound();
    notifyListeners();
  }

  /// Adds a life, up to a maximum of 3.
  void addLife() {
    if (_lives < 3) {
      _lives++;
      notifyListeners();
    }
  }

  /// Records that a hint has been used.
  void useHint() {
    if (_hintsUsed < _maxHints) {
      _hintsUsed++;
      notifyListeners();
    }
  }

  /// Grants an additional hint (e.g., from watching an ad).
  void addHint() {
    if (_hintsUsed > 0) {
      _hintsUsed--;
      notifyListeners();
    }
  }

  /// Cleans up resources when the provider is disposed.
  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
