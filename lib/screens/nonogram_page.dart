import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'nonogram_generator.dart';
import '../providers/game_provider.dart';
import '../animations/shake_animation.dart';
import '../game_state_manager.dart';
import '../services/firebase_service.dart';
import '../win_summary_dialog.dart';
import '../models.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import '../widgets/game_info_bar.dart';
import '../settings_manager.dart';
import '../managers/tutorial_manager.dart';
import '../widgets/tutorial_overlay.dart';


// Top-level function for background generation
NonogramPuzzle _generatePuzzleInBackground(Map<String, int> params) {
  final int size = params['size']!;
  return NonogramGenerator(size: size).generate();
}

enum CellState { empty, filled, marked }

class NonogramScreen extends StatefulWidget {
  final NonogramDifficulty difficulty;
  final int? dailyChallengeSeed;
  const NonogramScreen({super.key, required this.difficulty, this.dailyChallengeSeed});

  @override
  State<NonogramScreen> createState() => _NonogramScreenState();
}

class _NonogramScreenState extends State<NonogramScreen> {
  NonogramPuzzle? _puzzle;
  late List<List<CellState>> _userGrid;
  bool _isLoading = true;
  bool _isFillMode = true;
  bool _triggerShake = false;

  late List<bool> _completedRows;
  late List<bool> _completedCols;

  // Removed unused pan start tracking (assignments were present but value never read).
  final Set<Point<int>> _pannedCells = {};
  CellState? _panState;

  int _hintsUsed = 0;
  final int _maxHints = 3;

  int _correctlyFilledCount = 0;
  int _totalSolutionCells = 0;

  late ConfettiController _confettiController;
  GameProvider? _gameProvider;

  bool get isDailyChallenge => widget.dailyChallengeSeed != null;

  // --- Tutorial State ---
  int _tutorialStep = 0;
  bool _showTutorial = false;
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _toggleKey = GlobalKey();
  
  // A single instance of DeepCollectionEquality for comparing lists of clues.
  final DeepCollectionEquality _listEquals = const DeepCollectionEquality();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameProvider = Provider.of<GameProvider>(context, listen: false);
      _gameProvider!.addListener(_onGameStatusChanged);
      _startNewGame().then((_){
        _checkTutorialStatus();
      });
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _gameProvider?.removeListener(_onGameStatusChanged);
    super.dispose();
  }

  void _onGameStatusChanged() {
    if (!mounted) return;
    final status = _gameProvider?.status;
    if (status == GameStatus.won) {
      _handleWin();
    } else if (status == GameStatus.lost) {
      _showGameOverDialog();
    }
  }

  Future<void> _startNewGame() async {
    setState(() => _isLoading = true);
    final size = _getSizeForDifficulty(widget.difficulty);

    final newPuzzle = await compute(_generatePuzzleInBackground, {'size': size});

    if (mounted) {
      setState(() {
        _puzzle = newPuzzle;
        _totalSolutionCells = newPuzzle.solution.expand((row) => row).where((cell) => cell).length;
        _restartPuzzle();
        _isLoading = false;
      });
    }
  }

  void _restartPuzzle() {
    if (_puzzle == null) return;
    setState(() {
      _userGrid = List.generate(_puzzle!.rows, (_) => List.filled(_puzzle!.cols, CellState.empty));
      _completedRows = List.filled(_puzzle!.rows, false);
      _completedCols = List.filled(_puzzle!.cols, false);
      _hintsUsed = 0;
      _correctlyFilledCount = 0;
      context.read<GameProvider>().startGame();
      _checkCompletedLines();
    });
  }

  int _getSizeForDifficulty(NonogramDifficulty difficulty) {
    switch (difficulty) {
      case NonogramDifficulty.easy:
        return 5;
      case NonogramDifficulty.medium:
        return 10;
      case NonogramDifficulty.hard:
        return 15;
      case NonogramDifficulty.expert:
        return 20;
      case NonogramDifficulty.master:
        return 25;
    }
  }

  Future<void> _handleWin() async {
    _confettiController.play();
    final gameProvider = context.read<GameProvider>();
    final achievementsService = context.read<AchievementsService>();
    final timeTakenMillis = gameProvider.getElapsedMilliseconds();
    final points = (widget.difficulty.index + 1) * 150;

    if (isDailyChallenge) {
      await GameStateManager.markDailyAsCompleted(widget.dailyChallengeSeed!);
      await FirebaseService.instance.submitDailyChallengeScore(gameName: 'Nonogram', timeMillis: timeTakenMillis);
    } else {
      await GameStateManager.updateStats(gameName: 'Nonogram', timeTaken: timeTakenMillis, difficulty: widget.difficulty.name);
      achievementsService.checkAndUnlockAchievement(AchievementId.nonogramSolved1);
      if (gameProvider.mistakesMade == 0) {
        achievementsService.checkAndUnlockAchievement(AchievementId.nonogramMistakeFree);
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
          hintsUsed: _hintsUsed,
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

  /// Checks if the tutorial for this game has been completed.
  void _checkTutorialStatus() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final tutorialManager = Provider.of<TutorialManager>(context, listen: false);
      if (!tutorialManager.isTutorialCompleted('Nonogram')) {
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
      if (_tutorialStep > 2) {
        _showTutorial = false;
        Provider.of<TutorialManager>(context, listen: false).completeTutorial('Nonogram');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nonogram'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'How to Play',
            onPressed: () => _showInstructionsDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GameInfoBar(lives: game.lives, elapsedTime: game.elapsedTime),
                  const SizedBox(height: 16),
                  Expanded(child: _buildGameBoard()),
                  const SizedBox(height: 24),
                  _buildControls(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
          if (_showTutorial) _buildTutorialOverlay(),
        ],
      ),
    );
  }

  /// Builds the animated tutorial overlay for Nonogram.
  Widget _buildTutorialOverlay() {
    String text = '';
    Alignment alignment = Alignment.center;
    Rect highlightRect = Rect.zero;

    switch (_tutorialStep) {
      case 1:
        text = 'Welcome to Nonogram! The numbers are clues for filling in the grid to reveal a picture.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 2:
        text = 'Each number tells you the length of a block of filled cells. Use the buttons below to switch between filling cells and marking them with an X.';
        alignment = Alignment.topCenter;
        highlightRect = _getWidgetRect(_toggleKey);
        break;
    }

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
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(offset.dx - 8, offset.dy - 8, renderBox.size.width + 16, renderBox.size.height + 16);
    }
    return Rect.zero;
  }

  Widget _buildGameBoard() {
    if (_puzzle == null) return const SizedBox.shrink();

    return KeyedSubtree(
      key: _gridKey,
      child: ShakeAnimation(
        shake: _triggerShake,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final double totalHeight = constraints.maxHeight;

            final double clueFontSize = _getClueFontSize();
            final int maxRowCluesCount = _puzzle!.rowClues.map((c) => c.length).fold(0, max);
            final int maxColCluesCount = _puzzle!.colClues.map((c) => c.length).fold(0, max);

            final double rowCluesAreaWidth = (maxRowCluesCount * clueFontSize * 1.3 + 16).clamp(32.0, totalWidth * 0.4);
            final double colCluesAreaHeight = (maxColCluesCount * clueFontSize * 1.6 + 16).clamp(32.0, totalHeight * 0.4);

            final double availableGridWidth = totalWidth - rowCluesAreaWidth;
            final double availableGridHeight = totalHeight - colCluesAreaHeight;
            final double cellSize = min(availableGridWidth / _puzzle!.cols, availableGridHeight / _puzzle!.rows);
            if (cellSize <= 0) return const SizedBox.shrink();

            final double finalGridWidth = cellSize * _puzzle!.cols;
            final double finalGridHeight = cellSize * _puzzle!.rows;

            final double puzzleWidth = finalGridWidth + rowCluesAreaWidth;
            final double puzzleHeight = finalGridHeight + colCluesAreaHeight;

            return Center(
              child: SizedBox(
                width: puzzleWidth,
                height: puzzleHeight,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(width: rowCluesAreaWidth, height: colCluesAreaHeight),
                        _buildColClues(colCluesAreaHeight, cellSize),
                      ],
                    ),
                    Row(
                      children: [
                        _buildRowClues(rowCluesAreaWidth, cellSize),
                        SizedBox(
                          width: finalGridWidth,
                          height: finalGridHeight,
                          child: _buildGridCells(cellSize),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double _getClueFontSize() {
    switch (widget.difficulty) {
      case NonogramDifficulty.easy:
        return 14;
      case NonogramDifficulty.medium:
        return 12;
      case NonogramDifficulty.hard:
        return 10;
      case NonogramDifficulty.expert:
        return 9;
      case NonogramDifficulty.master:
        return 8;
    }
  }

  Widget _buildGridCells(double cellSize) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha:0.4), width: 1.5),
      ),
      child: GestureDetector(
        onTapDown: (details) {
          final col = (details.localPosition.dx / cellSize).floor();
          final row = (details.localPosition.dy / cellSize).floor();
          if (row >= 0 && row < _puzzle!.rows && col >= 0 && col < _puzzle!.cols) {
            _onCellTapped(row, col);
          }
        },
        onPanStart: (details) => _handlePan(details.localPosition, cellSize, isStart: true),
        onPanUpdate: (details) => _handlePan(details.localPosition, cellSize),
        onPanEnd: (details) {
          _pannedCells.clear();
            _panState = null;
          _checkForWin();
        },
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _puzzle!.rows * _puzzle!.cols,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _puzzle!.cols,
          ),
          itemBuilder: (context, index) {
            final row = index ~/ _puzzle!.cols;
            final col = index % _puzzle!.cols;
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  right: col < _puzzle!.cols - 1
                      ? BorderSide(
                      width: (col + 1) % 5 == 0 ? 1.5 : 0.5,
                      color: (col + 1) % 5 == 0
                          ? theme.colorScheme.onSurface.withValues(alpha:0.4)
                          : theme.dividerColor)
                      : BorderSide.none,
                  bottom: row < _puzzle!.rows - 1
                      ? BorderSide(
                      width: (row + 1) % 5 == 0 ? 1.5 : 0.5,
                      color: (row + 1) % 5 == 0
                          ? theme.colorScheme.onSurface.withValues(alpha:0.4)
                          : theme.dividerColor)
                      : BorderSide.none,
                ),
                color: _getCellColor(row, col),
              ),
              child: _userGrid[row][col] == CellState.marked
                  ? Icon(Icons.close, size: cellSize * 0.7, color: Colors.grey.shade600)
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildColClues(double height, double cellSize) {
    return SizedBox(
      height: height,
      width: _puzzle!.cols * cellSize,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_puzzle!.cols, (col) {
          final isCompleted = _completedCols[col];
          return SizedBox(
            width: cellSize,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _puzzle!.colClues[col]
                  .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  c.toString(),
                  style: TextStyle(
                    fontSize: _getClueFontSize(),
                    decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                    color: isCompleted ? Colors.grey : null,
                  ),
                ),
              ))
                  .toList(),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRowClues(double width, double cellSize) {
    return SizedBox(
      width: width,
      height: _puzzle!.rows * cellSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_puzzle!.rows, (row) {
          final isCompleted = _completedRows[row];
          return SizedBox(
            height: cellSize,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _puzzle!.rowClues[row]
                  .map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  c.toString(),
                  style: TextStyle(
                    fontSize: _getClueFontSize(),
                    decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                    color: isCompleted ? Colors.grey : null,
                  ),
                ),
              ))
                  .toList(),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildControls() {
    return KeyedSubtree(
      key: _toggleKey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionButton(
            icon: Icons.edit,
            label: 'Fill',
            onTap: () => setState(() => _isFillMode = true),
            isSelected: _isFillMode,
          ),
          const SizedBox(width: 12),
          _ActionButton(
            icon: Icons.close,
            label: 'Mark',
            onTap: () => setState(() => _isFillMode = false),
            isSelected: !_isFillMode,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        _ActionButton(icon: Icons.lightbulb_outline, label: 'Hint (${_maxHints - _hintsUsed})', onTap: _showHint),
        _ActionButton(icon: Icons.refresh, label: 'Restart', onTap: _restartPuzzle),
      ],
    );
  }

  Color _getCellColor(int row, int col) {
    final state = _userGrid[row][col];
    if (state == CellState.filled) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).canvasColor;
  }

  void _handlePan(Offset localPosition, double cellSize, {bool isStart = false}) {
    if (_puzzle == null) return;
    final int col = (localPosition.dx / cellSize).floor();
    final int row = (localPosition.dy / cellSize).floor();

    if (row < 0 || row >= _puzzle!.rows || col < 0 || col >= _puzzle!.cols) return;

    final currentCell = Point(row, col);

    if (isStart) {
      _panState = _isFillMode ? CellState.filled : CellState.marked;
      if(_userGrid[row][col] == _panState) {
        _panState = CellState.empty;
      }
      _pannedCells.add(currentCell);
      _updateCellState(row, col, fromPan: true);
    } else {
      if (_pannedCells.contains(currentCell)) return;

      _pannedCells.add(currentCell);
      _updateCellState(row, col, fromPan: true);
    }
  }

  void _onCellTapped(int row, int col) {
    _updateCellState(row, col);
    _checkForWin();
  }

  void _updateCellState(int row, int col, {bool fromPan = false}) {
    if (_puzzle == null) return;
    final settingsManager = context.read<SettingsManager>();
    if (settingsManager.isHapticsEnabled && !fromPan) HapticFeedback.lightImpact();

    final isCorrectSolution = _puzzle!.solution[row][col];
    final currentState = _userGrid[row][col];

    CellState nextState;

    if (fromPan) {
      nextState = _panState!;
    } else {
      if (_isFillMode) {
        nextState = (currentState == CellState.filled) ? CellState.empty : CellState.filled;
      } else {
        nextState = (currentState == CellState.marked) ? CellState.empty : CellState.marked;
      }
    }

    // Handle Mistakes
    if (nextState == CellState.filled && !isCorrectSolution) {
      if (!fromPan) _handleMistake();
      return;
    }

    // Update Counts for Win Condition
    if (currentState == CellState.filled && nextState != CellState.filled) {
      if(isCorrectSolution) _correctlyFilledCount--;
    } else if (currentState != CellState.filled && nextState == CellState.filled) {
      if(isCorrectSolution) _correctlyFilledCount++;
    }

    setState(() {
      _userGrid[row][col] = nextState;
    });

    _checkCompletedLines();
  }


  void _checkCompletedLines() {
    if (_puzzle == null) return;

    for (int r = 0; r < _puzzle!.rows; r++) {
      final userClues = _generateLineClues(_userGrid[r].map((s) => s == CellState.filled).toList());
      _completedRows[r] = _listEquals.equals(userClues, _puzzle!.rowClues[r]);
    }
    for (int c = 0; c < _puzzle!.cols; c++) {
      final colStates = List.generate(_puzzle!.rows, (r) => _userGrid[r][c] == CellState.filled);
      final userClues = _generateLineClues(colStates);
      _completedCols[c] = _listEquals.equals(userClues, _puzzle!.colClues[c]);
    }
    if(mounted) setState(() {});
  }

  List<int> _generateLineClues(List<bool> line) {
    final clues = <int>[];
    int currentRun = 0;
    for (final isFilled in line) {
      if (isFilled) {
        currentRun++;
      } else {
        if (currentRun > 0) clues.add(currentRun);
        currentRun = 0;
      }
    }
    if (currentRun > 0) clues.add(currentRun);
    return clues.isEmpty ? [] : clues;
  }

  void _handleMistake() {
    context.read<GameProvider>().handleMistake();
    setState(() {
      _triggerShake = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _triggerShake = false);
      });
    });
  }

  void _checkForWin() {
    if (_puzzle == null) return;

    if (_correctlyFilledCount != _totalSolutionCells) return;

    for (int r = 0; r < _puzzle!.rows; r++) {
      for (int c = 0; c < _puzzle!.cols; c++) {
        final shouldBeFilled = _puzzle!.solution[r][c];
        final isFilled = _userGrid[r][c] == CellState.filled;
        if (shouldBeFilled != isFilled) {
          return;
        }
      }
    }

    context.read<GameProvider>().winGame();
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Game Over'),
        content: const Text('You\'ve run out of lives!'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restartPuzzle();
              },
              child: const Text('Try Again')),
        ],
      ),
    );
  }

  void _showHint() {
    if (_puzzle == null || _hintsUsed >= _maxHints) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No more hints!")));
      return;
    }

    final incorrectCells = <Point<int>>[];
    for (int r = 0; r < _puzzle!.rows; r++) {
      for (int c = 0; c < _puzzle!.cols; c++) {
        final userState = _userGrid[r][c];
        final solution = _puzzle!.solution[r][c];
        if ((solution && userState != CellState.filled) || (!solution && userState == CellState.filled)) {
          incorrectCells.add(Point(r, c));
        }
      }
    }

    if (incorrectCells.isNotEmpty) {
      final hintCell = incorrectCells[Random().nextInt(incorrectCells.length)];
      final row = hintCell.x;
      final col = hintCell.y;

      setState(() {
        final currentState = _userGrid[row][col];
        final isSolutionFilled = _puzzle!.solution[row][col];

        if (isSolutionFilled && currentState != CellState.filled) {
          if (currentState == CellState.marked) {
            // No change in count
          } else {
            _correctlyFilledCount++;
          }
          _userGrid[row][col] = CellState.filled;
        } else if (!isSolutionFilled && currentState == CellState.filled) {
          _correctlyFilledCount--;
          _userGrid[row][col] = CellState.empty;
        } else {
          _userGrid[row][col] = isSolutionFilled ? CellState.filled : CellState.empty;
        }

        _hintsUsed++;
      });
      _checkCompletedLines();
      _checkForWin();
    }
  }

  void _showInstructionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play Nonogram'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("The goal is to color cells to reveal a hidden picture, based on the numbers provided for each row and column."),
              SizedBox(height: 16),
              Text("1. Clue Numbers", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Each number indicates the length of a solid block of filled cells in that row or column."),
              SizedBox(height: 16),
              Text("2. Gaps", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("If there are multiple numbers for a line (e.g., '2 3'), it means there are blocks of that length, in that order, separated by at least one empty cell."),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it!')),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;

  const _ActionButton({required this.icon, required this.label, this.onTap, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        foregroundColor: isSelected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onPrimary,
        backgroundColor: isSelected ? theme.colorScheme.secondaryContainer : theme.colorScheme.primary.withValues(alpha:0.8),
        elevation: 3,
      ),
    );
  }
}
