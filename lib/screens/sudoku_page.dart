import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'sudoku_generator.dart';
import '../providers/game_provider.dart';
import '../animations/shake_animation.dart';
import '../game_state_manager.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import '../win_summary_dialog.dart';
import '../widgets/game_info_bar.dart';
import '../settings_manager.dart';
import '../managers/tutorial_manager.dart';
import '../widgets/tutorial_overlay.dart';

/// Represents a single move (placing a number or note) for undo/redo functionality.
class SudokuMove {
  final Point<int> cell;
  final dynamic oldValue;
  final dynamic newValue;
  SudokuMove(this.cell, this.oldValue, this.newValue);
}

/// A top-level function designed to run in a separate isolate for generating Sudoku puzzles.
/// This prevents the UI from freezing while complex puzzles are being created.
SudokuPuzzle _generateSudokuInBackground(Map<String, dynamic> params) {
  final SudokuDifficulty difficulty = params['difficulty'];
  final int? seed = params['seed'];
  return SudokuGenerator.generate(difficulty: difficulty, seed: seed);
}

/// The main screen widget for the Sudoku game.
///
/// It manages the entire game lifecycle, from puzzle generation and user interaction
/// to win/loss conditions and integration with other services.
class SudokuScreen extends StatefulWidget {
  final SudokuDifficulty difficulty;
  final int? dailyChallengeSeed; // If not null, this indicates a daily challenge.

  const SudokuScreen({
    super.key,
    required this.difficulty,
    this.dailyChallengeSeed,
  });

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen>
    with WidgetsBindingObserver {
  // --- Game State Properties ---
  SudokuPuzzle? _puzzle;
  List<List<int>> _initialGrid = [];
  late List<List<dynamic>> _userGrid; // Can hold ints (numbers) or Sets<int> (notes).
  Point<int>? _selectedCell;
  int? _selectedNumber;
  Set<Point<int>> _errors = {};
  bool _isNoteMode = false;
  bool _isLoading = true;
  bool _triggerShake = false; // Controls the error shake animation.

  // --- Undo/Redo Stacks ---
  final List<SudokuMove> _undoStack = [];
  final List<SudokuMove> _redoStack = [];

  // --- UI and Animation Controllers ---
  late ConfettiController _confettiController;
  GameProvider? _gameProvider;

  bool get isDailyChallenge => widget.dailyChallengeSeed != null;

  // --- Tutorial State ---
  int _tutorialStep = 0;
  bool _showTutorial = false;
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _numberPadKey = GlobalKey();
  final GlobalKey _noteButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    AdService.instance.loadRewardedAd(); // Pre-load a rewarded ad.

    // All game initialization logic is deferred until the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameProvider = Provider.of<GameProvider>(context, listen: false);
      _gameProvider!.addListener(_onGameStatusChanged);
      _startNewGame().then((_) {
        // Check tutorial status after the game has loaded.
        _checkTutorialStatus();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    _gameProvider?.removeListener(_onGameStatusChanged);
    super.dispose();
  }

  /// Listens to the global game status and triggers appropriate UI responses.
  void _onGameStatusChanged() {
    if (!mounted) return;
    final status = _gameProvider?.status;
    if (status == GameStatus.won) {
      _handleWin();
    } else if (status == GameStatus.lost) {
      _promptForExtraLife();
    }
  }

  /// Starts a new game by generating a puzzle in the background.
  Future<void> _startNewGame() async {
    setState(() => _isLoading = true);
    // Use `compute` to offload the heavy work of puzzle generation to a separate isolate.
    final newPuzzle = await compute(_generateSudokuInBackground, {
      'difficulty': widget.difficulty,
      'seed': widget.dailyChallengeSeed,
    });
    if (mounted) {
      setState(() {
        _puzzle = newPuzzle;
        _initialGrid = _puzzle!.puzzle;
        _restartPuzzle();
        _isLoading = false;
      });
    }
  }

  /// Resets the game board and all related state variables to start a fresh puzzle.
  void _restartPuzzle() {
    setState(() {
      _userGrid = List.generate(9, (r) => List.from(_initialGrid[r]));
      _selectedCell = null;
      _selectedNumber = null;
      _isNoteMode = false;
      _errors = {};
      _undoStack.clear();
      _redoStack.clear();
      context.read<GameProvider>().startGame();
    });
  }

  /// Checks if the tutorial for this game has been completed.
  void _checkTutorialStatus() {
    // Wait a moment for the UI to be fully built.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final tutorialManager =
          Provider.of<TutorialManager>(context, listen: false);
      if (!tutorialManager.isTutorialCompleted('Sudoku')) {
        setState(() {
          _showTutorial = true;
          _tutorialStep = 1;
        });
      }
    });
  }

  /// Advances the tutorial to the next step or completes it.
  void _nextTutorialStep() {
    setState(() {
      _tutorialStep++;
      if (_tutorialStep > 3) {
        _showTutorial = false;
        Provider.of<TutorialManager>(context, listen: false)
            .completeTutorial('Sudoku');
      }
    });
  }

  /// Handles the win condition: plays confetti, saves stats, and shows a summary dialog.
  Future<void> _handleWin() async {
    _confettiController.play();
    final gameProvider = context.read<GameProvider>();
    final achievementsService = context.read<AchievementsService>();
    final timeTaken = gameProvider.getElapsedMilliseconds();
    final points = (widget.difficulty.index + 1) * 100;

    if (isDailyChallenge) {
      await GameStateManager.markDailyAsCompleted(widget.dailyChallengeSeed!);
      await FirebaseService.instance
          .submitDailyChallengeScore(gameName: 'Sudoku', timeMillis: timeTaken);
    } else {
      final stats = await GameStateManager.loadGameStats();
      final puzzlesSolved = (stats['Sudoku']?.puzzlesSolved ?? 0) + 1;

      await GameStateManager.updateStats(
          gameName: 'Sudoku', timeTaken: timeTaken, difficulty: widget.difficulty.name);

      // Check and unlock relevant achievements.
      achievementsService
          .checkAndUnlockAchievement(AchievementId.sudokuSolved1);
      if (puzzlesSolved >= 10) {
        achievementsService
            .checkAndUnlockAchievement(AchievementId.sudokuSolved10);
      }
      if (widget.difficulty == SudokuDifficulty.hard) {
        achievementsService
            .checkAndUnlockAchievement(AchievementId.sudokuHard);
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WinSummaryDialog(
          timeTaken: gameProvider.elapsedTime,
          difficulty: widget.difficulty.name,
          points: points,
          hintsUsed: gameProvider.hintsUsed,
          mistakesMade: gameProvider.mistakesMade,
          onPlayAgain: isDailyChallenge
              ? null
              : () {
                  Navigator.of(dialogContext).pop();
                  _startNewGame();
                },
          onDone: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }

  /// Checks if the puzzle is fully and correctly solved.
  void _checkForWin() {
    // A puzzle is solved if there are no empty cells (0s or note sets) and no errors.
    bool isSolved =
        !_userGrid.any((row) => row.any((cell) => cell == 0 || cell is Set));
    if (isSolved && _errors.isEmpty) {
      context.read<GameProvider>().winGame();
    }
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isDailyChallenge ? 'Daily Sudoku' : 'Sudoku'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'How to Play',
              onPressed: () => _showInstructionsDialog(context)),
        ],
      ),
      body: Stack(
        children: [
          // A subtle gradient background for visual appeal.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha:0.1),
                  theme.colorScheme.secondary.withValues(alpha:0.1),
                ],
              ),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        GameInfoBar(
                            lives: game.lives, elapsedTime: game.elapsedTime),
                        const SizedBox(height: 16),
                        Expanded(child: Center(child: _buildGrid())),
                        const SizedBox(height: 24),
                        _buildNumberPad(),
                        const SizedBox(height: 20),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
          // Confetti overlay for win animation.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
          if (_showTutorial) _buildTutorialOverlay(),
        ],
      ),
    );
  }

  // --- UI Building Helper Methods ---

  /// Builds the animated tutorial overlay.
  Widget _buildTutorialOverlay() {
    String text = '';
    Alignment alignment = Alignment.center;
    Rect highlightRect = Rect.zero;

    // Determine the text and highlight area for the current tutorial step.
    switch (_tutorialStep) {
      case 1:
        text = 'Welcome to Sudoku! Tap on an empty cell to select it.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 2:
        text =
            'Now, use the number pad to fill in the selected cell with the correct number.';
        alignment = Alignment.topCenter;
        highlightRect = _getWidgetRect(_numberPadKey);
        break;
      case 3:
        text =
            'You can also switch to Note Mode to pencil in possibilities for a cell.';
        alignment = Alignment.topCenter;
        highlightRect = _getWidgetRect(_noteButtonKey);
        break;
    }

    // Animate the appearance of the overlay.
    return AnimatedOpacity(
      opacity: _showTutorial ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: TutorialOverlay(
        text: text,
        onNext: _nextTutorialStep,
        alignment: alignment,
        highlightRect: highlightRect,
      ),
    );
  }

  /// Calculates the screen position and size of a widget from its GlobalKey.
  Rect _getWidgetRect(GlobalKey key) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      // Add padding to the highlight rect for better visuals.
      return Rect.fromLTWH(offset.dx - 8, offset.dy - 8,
          renderBox.size.width + 16, renderBox.size.height + 16);
    }
    return Rect.zero;
  }

  /// Builds the main 9x9 Sudoku grid.
  Widget _buildGrid() {
    return ShakeAnimation(
      shake: _triggerShake,
      // Attach the GlobalKey to the widget we want to highlight.
      child: KeyedSubtree(
        key: _gridKey,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha:0.5),
                    width: 2.5),
                borderRadius: BorderRadius.circular(8)),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 81,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 9),
              itemBuilder: (context, index) {
                final row = index ~/ 9;
                final col = index % 9;
                return _buildCell(row, col);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single cell of the Sudoku grid with appropriate styling and content.
  Widget _buildCell(int row, int col) {
    final cellValue = _userGrid[row][col];
    final isInitial = _initialGrid[row][col] != 0;
    final isSelected = _selectedCell?.x == row && _selectedCell?.y == col;
    final inSelectedRowCol = _selectedCell != null &&
        (_selectedCell!.x == row || _selectedCell!.y == col);
    final inSelectedBox = _selectedCell != null &&
        (row ~/ 3 == _selectedCell!.x ~/ 3) &&
        (col ~/ 3 == _selectedCell!.y ~/ 3);
    final hasError = _errors.contains(Point(row, col));
    final isHighlighted = _selectedNumber != null &&
        cellValue is int &&
        cellValue != 0 &&
        cellValue == _selectedNumber;
    final theme = Theme.of(context);

    Color backgroundColor;
    if (isSelected) {
      backgroundColor = theme.colorScheme.primary.withValues(alpha:0.4);
    } else if (isHighlighted) {
      backgroundColor = theme.colorScheme.secondary.withValues(alpha:0.2);
    } else if (inSelectedRowCol || inSelectedBox) {
      backgroundColor = theme.colorScheme.primary.withValues(alpha:0.1);
    } else {
      backgroundColor = Colors.transparent;
    }

    Widget cellChild;
    if (cellValue is Set<int>) {
      cellChild = _buildNotesGrid(cellValue);
    } else if (cellValue is int && cellValue != 0) {
      cellChild = Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Text(
            '$cellValue',
            key: ValueKey<int>(cellValue),
            style: TextStyle(
              fontSize: 28,
              fontWeight: isInitial ? FontWeight.bold : FontWeight.w500,
              color: hasError
                  ? theme.colorScheme.error
                  : (isInitial ? null : theme.colorScheme.primary),
            ),
          ),
        ),
      );
    } else {
      cellChild = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => setState(() {
        _selectedCell = Point(row, col);
        if (!isInitial && cellValue is int && cellValue != 0) {
          _selectedNumber = cellValue;
        } else if (isInitial) {
          _selectedNumber = cellValue;
        } else {
          _selectedNumber = null;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(
                width: row % 3 == 0 ? 1.5 : 0.5,
                color: row % 3 == 0
                    ? theme.colorScheme.onSurface.withValues(alpha:0.5)
                    : theme.dividerColor.withValues(alpha:0.5)),
            left: BorderSide(
                width: col % 3 == 0 ? 1.5 : 0.5,
                color: col % 3 == 0
                    ? theme.colorScheme.onSurface.withValues(alpha:0.5)
                    : theme.dividerColor.withValues(alpha:0.5)),
            right: col == 8
                ? BorderSide(
                    width: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha:0.5))
                : BorderSide.none,
            bottom: row == 8
                ? BorderSide(
                    width: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha:0.5))
                : BorderSide.none,
          ),
        ),
        child: cellChild,
      ),
    );
  }

  /// Builds the 3x3 grid inside a cell for displaying notes.
  Widget _buildNotesGrid(Set<int> notes) {
    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 9,
      itemBuilder: (context, index) {
        final number = index + 1;
        return Center(
          child: Text(
            notes.contains(number) ? '$number' : '',
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.secondary),
          ),
        );
      },
    );
  }

  /// Builds the number pad for user input.
  Widget _buildNumberPad() {
    return KeyedSubtree(
      key: _numberPadKey,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4.0,
        runSpacing: 4.0,
        children: List.generate(9, (index) {
          final number = index + 1;
          return _NumberButton(
            number: number,
            isSelected: _selectedNumber == number,
            onTap: () => _onNumberPressed(number),
          );
        }),
      ),
    );
  }

  /// Builds the row of action buttons (Undo, Redo, Hint, etc.).
  Widget _buildActionButtons() {
    final gameProvider = context.watch<GameProvider>();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12.0,
      runSpacing: 8.0,
      children: [
        _ActionButton(
            icon: Icons.undo,
            label: 'Undo',
            onTap: _undoStack.isEmpty ? null : _undo),
        _ActionButton(
            icon: Icons.redo,
            label: 'Redo',
            onTap: _redoStack.isEmpty ? null : _redo),
        KeyedSubtree(
          key: _noteButtonKey,
          child: _ActionButton(
            icon: _isNoteMode ? Icons.edit_off : Icons.edit,
            label: _isNoteMode ? 'Note' : 'Num',
            onTap: () => setState(() => _isNoteMode = !_isNoteMode),
            isSelected: _isNoteMode,
          ),
        ),
        _ActionButton(
            icon: Icons.lightbulb_outline,
            label: 'Hint (${gameProvider.maxHints - gameProvider.hintsUsed})',
            onTap: _showHint),
        _ActionButton(
            icon: Icons.backspace_outlined,
            label: 'Erase',
            onTap: _onErasePressed),
        if (!isDailyChallenge)
          _ActionButton(
              icon: Icons.refresh, label: 'Restart', onTap: _restartPuzzle),
      ],
    );
  }

  // --- User Interaction and Game Logic Methods ---

  /// Triggers a haptic feedback vibration if enabled in settings.
  void _handleHapticFeedback() {
    final settingsManager =
        Provider.of<SettingsManager>(context, listen: false);
    if (settingsManager.isHapticsEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  /// Handles a tap on the number pad, placing a number or a note.
  void _onNumberPressed(int number) {
    _handleHapticFeedback();
    if (_selectedCell != null &&
        !_isInitialValue(_selectedCell!.x, _selectedCell!.y)) {
      final r = _selectedCell!.x;
      final c = _selectedCell!.y;
      final oldValue = _userGrid[r][c];

      if (_isNoteMode) {
        Set<int> notes = (oldValue is Set<int>) ? Set.from(oldValue) : {};
        if (notes.contains(number)) {
          notes.remove(number);
        } else {
          notes.add(number);
        }
        final newValue = notes.isEmpty ? 0 : notes;
        _recordMove(Point(r, c), oldValue, newValue);
        setState(() => _userGrid[r][c] = newValue);
      } else {
        final newValue = _userGrid[r][c] == number ? 0 : number;
        _recordMove(Point(r, c), oldValue, newValue);
        setState(() {
          _userGrid[r][c] = newValue;
          _selectedNumber = newValue == 0 ? null : newValue;
          if (newValue != 0) _autoClearNotes(r, c, newValue);
          _validateBoard();
          _checkForWin();
        });
      }
    } else {
      setState(
          () => _selectedNumber = (_selectedNumber == number) ? null : number);
    }
  }

  /// Handles a tap on the erase button.
  void _onErasePressed() {
    _handleHapticFeedback();
    if (_selectedCell != null &&
        !_isInitialValue(_selectedCell!.x, _selectedCell!.y)) {
      final r = _selectedCell!.x;
      final c = _selectedCell!.y;
      final oldValue = _userGrid[r][c];
      if (oldValue == 0) return;
      _recordMove(Point(r, c), oldValue, 0);
      setState(() {
        _userGrid[r][c] = 0;
        _validateBoard();
      });
    }
  }

  /// Records a move to the undo stack and clears the redo stack.
  void _recordMove(Point<int> cell, dynamic oldValue, dynamic newValue) {
    if (oldValue.toString() == newValue.toString()) return;
    setState(() {
      _undoStack.add(SudokuMove(cell, oldValue, newValue));
      _redoStack.clear();
    });
  }

  /// Reverts the last move from the undo stack.
  void _undo() {
    if (_undoStack.isEmpty) return;
    _handleHapticFeedback();
    setState(() {
      final move = _undoStack.removeLast();
      _userGrid[move.cell.x][move.cell.y] = move.oldValue;
      _redoStack.add(move);
      _validateBoard();
    });
  }

  /// Re-applies the last undone move from the redo stack.
  void _redo() {
    if (_redoStack.isEmpty) return;
    _handleHapticFeedback();
    setState(() {
      final move = _redoStack.removeLast();
      _userGrid[move.cell.x][move.cell.y] = move.newValue;
      _undoStack.add(move);
      _validateBoard();
    });
  }

  /// Automatically removes notes of a certain number from the same row, column, and box.
  void _autoClearNotes(int row, int col, int number) {
    for (int i = 0; i < 9; i++) {
      if (_userGrid[row][i] is Set<int>) {
        (_userGrid[row][i] as Set<int>).remove(number);
      }
      if (_userGrid[i][col] is Set<int>) {
        (_userGrid[i][col] as Set<int>).remove(number);
      }
    }
    final startRow = (row ~/ 3) * 3;
    final startCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (_userGrid[startRow + r][startCol + c] is Set<int>) {
          (_userGrid[startRow + r][startCol + c] as Set<int>).remove(number);
        }
      }
    }
  }

  /// Validates the entire board and updates the set of error cells.
  void _validateBoard({bool isInitialLoad = false}) {
    final oldErrors = Set<Point<int>>.from(_errors);
    final newErrors = <Point<int>>{};
    for (int i = 0; i < 9; i++) {
      _findDuplicates(newErrors, _getRow(i));
      _findDuplicates(newErrors, _getCol(i));
      _findDuplicates(newErrors, _getBox(i));
    }

    final newlyFoundErrors = newErrors.difference(oldErrors);
    if (!isInitialLoad && newlyFoundErrors.isNotEmpty) {
      _handleMistake();
    }
    setState(() => _errors = newErrors);
  }

  /// Finds duplicate numbers within a given unit (row, column, or box).
  void _findDuplicates(Set<Point<int>> errors, List<Point<int>> unit) {
    final seen = <int, List<Point<int>>>{};
    for (final point in unit) {
      final value = _userGrid[point.x][point.y];
      if (value is int && value != 0) {
        seen.putIfAbsent(value, () => []).add(point);
      }
    }
    for (final entry in seen.entries) {
      if (entry.value.length > 1) errors.addAll(entry.value);
    }
  }

  /// Handles the hint button tap, providing a hint or prompting to watch an ad.
  void _showHint() {
    if (_puzzle == null || _isLoading) return;
    final gameProvider = context.read<GameProvider>();
    if (gameProvider.hintsUsed >= gameProvider.maxHints) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Out of Hints!'),
          content: const Text('Watch a short ad to get another hint?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No Thanks'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                AdService.instance.showRewardedAd(onRewardEarned: () {
                  gameProvider.addHint();
                });
              },
              child: const Text('Watch Ad'),
            ),
          ],
        ),
      );
      return;
    }
    _useHint();
  }

  /// Finds an incorrect or empty cell and reveals the correct number.
  void _useHint() {
    List<Point<int>> possibleHints = [];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final userVal = _userGrid[r][c];
        final solutionVal = _puzzle!.solution[r][c];
        if ((userVal is int && userVal != solutionVal) || userVal is Set) {
          possibleHints.add(Point(r, c));
        }
      }
    }

    if (possibleHints.isNotEmpty) {
      possibleHints.shuffle();
      final hintCell = possibleHints.first;
      final r = hintCell.x;
      final c = hintCell.y;
      final oldValue = _userGrid[r][c];
      final newValue = _puzzle!.solution[r][c];

      context.read<GameProvider>().useHint();
      _recordMove(Point(r, c), oldValue, newValue);
      setState(() {
        _userGrid[r][c] = newValue;
        _validateBoard();
        _checkForWin();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("The board is correct so far!")));
    }
  }

  /// Shows the "How to Play" instructions dialog.
  void _showInstructionsDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('How to Play Sudoku'),
              content: const SingleChildScrollView(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      "The objective is to fill a 9x9 grid so that each column, each row, and each of the nine 3x3 subgrids contain all of the digits from 1 to 9."),
                  SizedBox(height: 16),
                  Text("1. No number can be repeated in the same row.",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("2. No number can be repeated in the same column.",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("3. No number can be repeated in the same 3x3 box.",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it!'))
              ],
            ));
  }

  /// Handles a mistake by decrementing lives and triggering a shake animation.
  void _handleMistake() {
    context.read<GameProvider>().handleMistake();
    setState(() {
      _triggerShake = true;
      Future.delayed(const Duration(milliseconds: 500),
          () => setState(() => _triggerShake = false));
    });
  }
  
  /// Prompts the user to watch a rewarded ad for an extra life.
  void _promptForExtraLife() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Out of Lives!'),
        content:
            const Text('Watch a short ad to get an extra life and continue playing?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showGameOverDialog();
            },
            child: const Text('No Thanks'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              AdService.instance.showRewardedAd(onRewardEarned: () {
                context.read<GameProvider>().addLife();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You got an extra life!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              });
            },
            child: const Text('Watch Ad'),
          ),
        ],
      ),
    );
  }
  
  /// Shows the final game over dialog when the user has no lives left.
  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content:
            const Text('You have run out of lives! Would you like to try again?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Menu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartPuzzle();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // --- Utility Methods ---
  bool _isInitialValue(int row, int col) =>
      _initialGrid.isNotEmpty && _initialGrid[row][col] != 0;
  List<Point<int>> _getRow(int r) => List.generate(9, (c) => Point(r, c));
  List<Point<int>> _getCol(int c) => List.generate(9, (r) => Point(r, c));
  List<Point<int>> _getBox(int i) {
    final startRow = (i ~/ 3) * 3;
    final startCol = (i % 3) * 3;
    return [
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++) Point(startRow + r, startCol + c)
    ];
  }
}

// --- Custom UI Widget Components ---

/// A custom, animated button for the number pad.
class _NumberButton extends StatefulWidget {
  final int number;
  final bool isSelected;
  final VoidCallback onTap;

  const _NumberButton(
      {required this.number, required this.isSelected, required this.onTap});

  @override
  State<_NumberButton> createState() => _NumberButtonState();
}

class _NumberButtonState extends State<_NumberButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5);
    final fgColor = widget.isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: _isPressed || widget.isSelected
              ? null
              : [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha:0.2),
                    blurRadius: 5,
                    offset: const Offset(2, 2),
                  ),
                  BoxShadow(
                    color: theme.colorScheme.surface.withValues(alpha:0.9),
                    blurRadius: 5,
                    offset: const Offset(-2, -2),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            '${widget.number}',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: fgColor),
          ),
        ),
      ),
    );
  }
}

/// A custom, styled button for the action bar (Undo, Hint, etc.).
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;

  const _ActionButton(
      {required this.icon,
      required this.label,
      this.onTap,
      this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, semanticLabel: label),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        foregroundColor: isSelected
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onPrimary,
        backgroundColor: isSelected
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.primary.withValues(alpha:0.8),
        elevation: 3,
      ),
    );
  }
}

