import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'futoshi_generator.dart';
import '../providers/game_provider.dart';
import '../animations/shake_animation.dart';
import '../game_state_manager.dart';
import '../win_summary_dialog.dart';
import '../services/firebase_service.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import '../widgets/game_info_bar.dart';
import '../managers/tutorial_manager.dart';
import '../widgets/tutorial_overlay.dart';

// --- Data Structures ---

enum FutoshiDifficulty { easy, medium, hard, expert, master }

class FutoshiConstraint {
  final Point<int> from;
  final Point<int> to;
  const FutoshiConstraint({required this.from, required this.to});

  Map<String, dynamic> toJson() => {
        'from': {'x': from.x, 'y': from.y},
        'to': {'x': to.x, 'y': to.y},
      };

  static FutoshiConstraint fromJson(Map<String, dynamic> json) => FutoshiConstraint(
        from: Point(json['from']['x'], json['from']['y']),
        to: Point(json['to']['x'], json['to']['y']),
      );
}

class FutoshiPuzzle {
  final int size;
  final List<List<int>> initialGrid;
  final List<FutoshiConstraint> constraints;
  final List<List<int>> solution; // For hint system

  const FutoshiPuzzle({
    required this.size,
    required this.initialGrid,
    required this.constraints,
    required this.solution,
  });

  Map<String, dynamic> toJson() => {
        'size': size,
        'initialGrid': initialGrid,
        'constraints': constraints.map((c) => c.toJson()).toList(),
        'solution': solution,
      };

  static FutoshiPuzzle fromJson(Map<String, dynamic> json) => FutoshiPuzzle(
        size: json['size'],
        initialGrid: (json['initialGrid'] as List).map((row) => (row as List).map((e) => e as int).toList()).toList(),
        constraints: (json['constraints'] as List).map((c) => FutoshiConstraint.fromJson(c)).toList(),
        solution: (json['solution'] as List).map((row) => (row as List).map((e) => e as int).toList()).toList(),
      );
}

// Top-level function for background generation
FutoshiPuzzle _generateFutoshiInBackground(Map<String, int> params) {
  final int size = params['size']!;
  final int constraints = params['constraints']!;
  return FutoshiGenerator(size: size, difficulty: constraints).generate();
}

// --- Main Widget ---

class FutoshiScreen extends StatefulWidget {
  final FutoshiDifficulty difficulty;
  final int? dailyChallengeSeed;
  const FutoshiScreen({super.key, required this.difficulty, this.dailyChallengeSeed});

  @override
  State<FutoshiScreen> createState() => _FutoshiScreenState();
}

class _FutoshiScreenState extends State<FutoshiScreen> with WidgetsBindingObserver {
  // --- Game State ---
  FutoshiPuzzle? _puzzle;
  late List<List<int>> _userGrid;
  Point<int>? _selectedCell;
  Set<Point<int>> _errors = {};
  bool _isLoading = true;
  bool _triggerShake = false;
  int _hintsUsed = 0;
  final int _maxHints = 1;

  late ConfettiController _confettiController;
  GameProvider? _gameProvider;

  bool get isDailyChallenge => widget.dailyChallengeSeed != null;

  // --- Tutorial State ---
  int _tutorialStep = 0;
  bool _showTutorial = false;
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _numberPadKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    final initialGameProvider = Provider.of<GameProvider>(context, listen: false);
     WidgetsBinding.instance.addPostFrameCallback((_) async {
      _gameProvider = initialGameProvider;
      _gameProvider!.addListener(_onGameStatusChanged);
      await _startNewGame();
      if (!mounted) return;
      _checkTutorialStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final settings = _getSettingsForDifficulty(widget.difficulty);

    final newPuzzle = await compute(_generateFutoshiInBackground, settings);

    if (mounted) {
      setState(() {
        _puzzle = newPuzzle;
        _restartPuzzle();
        _isLoading = false;
      });
    }
  }

  void _restartPuzzle() {
    if (_puzzle == null) return;
    setState(() {
      _userGrid = List.generate(_puzzle!.size, (r) => List.generate(_puzzle!.size, (c) => _puzzle!.initialGrid[r][c]));
      _selectedCell = null;
      _errors = {};
      _hintsUsed = 0;
      context.read<GameProvider>().startGame();
    });
  }

  Map<String, int> _getSettingsForDifficulty(FutoshiDifficulty difficulty) {
    switch (difficulty) {
      case FutoshiDifficulty.easy:
        return {'size': 4, 'constraints': 3};
      case FutoshiDifficulty.medium:
        return {'size': 5, 'constraints': 5};
      case FutoshiDifficulty.hard:
        return {'size': 6, 'constraints': 8};
      case FutoshiDifficulty.expert:
        return {'size': 6, 'constraints': 10};
      case FutoshiDifficulty.master:
        return {'size': 7, 'constraints': 12};
    }
  }

   Future<void> _handleWin() async {
    _confettiController.play();
    final gameProvider = _gameProvider;
    if (gameProvider == null) return;
    final achievementsService = Provider.of<AchievementsService>(context, listen: false);

    final timeTakenMillis = gameProvider.getElapsedMilliseconds();
    final points = (widget.difficulty.index + 1) * 150;

    if (isDailyChallenge) {
      await GameStateManager.markDailyAsCompleted(widget.dailyChallengeSeed!);
      await FirebaseService.instance.submitDailyChallengeScore(gameName: 'Futoshi', timeMillis: timeTakenMillis);
    } else {
      await GameStateManager.updateStats(gameName: 'Futoshi', timeTaken: timeTakenMillis, difficulty: widget.difficulty.name);
    }

    achievementsService.checkAndUnlockAchievement(AchievementId.futoshiSolved1);

    if (!mounted) return;
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
            ));
  }

  /// Checks if the tutorial for this game has been completed.
  void _checkTutorialStatus() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final tutorialManager = Provider.of<TutorialManager>(context, listen: false);
      if (!tutorialManager.isTutorialCompleted('Futoshi')) {
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
        Provider.of<TutorialManager>(context, listen: false).completeTutorial('Futoshi');
      }
    });
  }

   @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Futoshi'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.help_outline), tooltip: 'How to Play', onPressed: () => _showInstructionsDialog(context))],
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
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        GameInfoBar(lives: game.lives, elapsedTime: game.elapsedTime),
                        const SizedBox(height: 16),
                        Expanded(child: Center(child: _buildGameBoard())),
                        const SizedBox(height: 24),
                        if (_puzzle != null) _buildNumberPad(),
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

  /// Builds the animated tutorial overlay for Futoshi.
  Widget _buildTutorialOverlay() {
    String text = '';
    Alignment alignment = Alignment.center;
    Rect highlightRect = Rect.zero;

    switch (_tutorialStep) {
      case 1:
        text = 'Welcome to Futoshi! Fill the grid so each number appears only once per row and column.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 2:
        text = 'The > and < symbols are inequality constraints. The numbers in the cells must follow these rules.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 3:
        text = 'Use the number pad to enter your answers.';
        alignment = Alignment.topCenter;
        highlightRect = _getWidgetRect(_numberPadKey);
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
    final gridSize = _puzzle!.size;
    final totalItems = gridSize * 2 - 1;
    return KeyedSubtree(
      key: _gridKey,
      child: ShakeAnimation(
        shake: _triggerShake,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalItems * totalItems,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: totalItems),
            itemBuilder: (context, index) {
              final gridX = index % totalItems, gridY = index ~/ totalItems;
              if (gridX % 2 == 0 && gridY % 2 == 0) {
                return _buildCell(gridY ~/ 2, gridX ~/ 2);
              } else {
                return _buildConstraint(gridY, gridX);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    if (_puzzle == null) return const SizedBox.shrink();
    final isSelected = _selectedCell == Point(row, col);
    final isInitial = _puzzle!.initialGrid[row][col] != 0;
    final hasError = _errors.contains(Point(row, col));
    final number = _userGrid[row][col];
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: isInitial ? null : () => setState(() => _selectedCell = Point(row, col)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha:0.4) : Colors.transparent,
          border: Border.all(color: hasError ? theme.colorScheme.error : theme.dividerColor.withValues(alpha:0.5), width: hasError ? 2.0 : 1.0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: number == 0
                ? const SizedBox.shrink()
                : Text(
                    '$number',
                     key: ValueKey<int>(number),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: isInitial ? FontWeight.bold : FontWeight.w500,
                      color: hasError ? theme.colorScheme.error : (isInitial ? null : theme.colorScheme.primary),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildConstraint(int gridY, int gridX) {
    if (_puzzle == null) return const SizedBox.shrink();
    String symbol = '';
    if (gridY % 2 == 0 && gridX % 2 != 0) {
      final p1 = Point(gridY ~/ 2, (gridX - 1) ~/ 2);
      final p2 = Point(gridY ~/ 2, (gridX + 1) ~/ 2);
      for (final c in _puzzle!.constraints) {
        if (c.from == p1 && c.to == p2) symbol = '>';
        if (c.from == p2 && c.to == p1) symbol = '<';
      }
    } else if (gridY % 2 != 0 && gridX % 2 == 0) {
      final p1 = Point((gridY - 1) ~/ 2, gridX ~/ 2);
      final p2 = Point((gridY + 1) ~/ 2, gridX ~/ 2);
      for (final c in _puzzle!.constraints) {
        if (c.from == p1 && c.to == p2) symbol = 'v';
        if (c.from == p2 && c.to == p1) symbol = '^';
      }
    }
    return Center(child: Text(symbol, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)));
  }

  Widget _buildNumberPad() {
    return KeyedSubtree(
      key: _numberPadKey,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.0,
        runSpacing: 8.0,
        children: List.generate(_puzzle!.size, (index) {
          final number = index + 1;
          return _NumberButton(
            number: number,
            onTap: () => _onNumberPressed(number),
          );
        }),
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
        _ActionButton(icon: Icons.backspace_outlined, label: 'Erase', onTap: _onErasePressed),
        _ActionButton(icon: Icons.refresh, label: 'Restart', onTap: _restartPuzzle),
      ],
    );
  }

  void _onNumberPressed(int number) {
    if (_selectedCell != null) {
      setState(() {
        final currentVal = _userGrid[_selectedCell!.x][_selectedCell!.y];
        _userGrid[_selectedCell!.x][_selectedCell!.y] = (currentVal == number) ? 0 : number;
        _validateBoard();
        _checkForWin();
      });
    }
  }

  void _onErasePressed() {
    if (_selectedCell != null) {
      setState(() {
        _userGrid[_selectedCell!.x][_selectedCell!.y] = 0;
        _validateBoard();
      });
    }
  }

  void _validateBoard({bool isInitialLoad = false}) {
    if (_puzzle == null) return;
    final oldErrors = Set<Point<int>>.from(_errors);
    final newErrors = <Point<int>>{};
    final size = _puzzle!.size;
    for (int i = 0; i < size; i++) {
      final rowCounts = <int, List<int>>{}, colCounts = <int, List<int>>{};
      for (int j = 0; j < size; j++) {
        final rowVal = _userGrid[i][j];
        if (rowVal != 0) rowCounts.putIfAbsent(rowVal, () => []).add(j);
        final colVal = _userGrid[j][i];
        if (colVal != 0) colCounts.putIfAbsent(colVal, () => []).add(j);
      }
      rowCounts.forEach((_, cols) {
        if (cols.length > 1) newErrors.addAll(cols.map((c) => Point(i, c)));
      });
      colCounts.forEach((_, rows) {
        if (rows.length > 1) newErrors.addAll(rows.map((r) => Point(r, i)));
      });
    }
    for (final c in _puzzle!.constraints) {
      final from = _userGrid[c.from.x][c.from.y], to = _userGrid[c.to.x][c.to.y];
      if (from != 0 && to != 0 && from <= to) {
        newErrors.add(c.from);
        newErrors.add(c.to);
      }
    }

    if (!isInitialLoad && newErrors.difference(oldErrors).isNotEmpty) {
      _handleMistake();
    }
    setState(() => _errors = newErrors);
  }

  void _handleMistake() {
    context.read<GameProvider>().handleMistake();
    setState(() {
      _triggerShake = true;
      Future.delayed(const Duration(milliseconds: 500), () => setState(() => _triggerShake = false));
    });
  }

  void _checkForWin() {
    if (_puzzle == null) return;
    if (!_userGrid.any((r) => r.any((c) => c == 0)) && _errors.isEmpty) {
      context.read<GameProvider>().winGame();
    }
  }

  void _showGameOverDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
              title: const Text('Game Over'),
              content: const Text('You have run out of lives!'),
              actions: [TextButton(onPressed: () {
                    Navigator.of(context).pop();
                    _restartPuzzle();
                  }, child: const Text('Try Again'))],
            ));
  }

  void _showHint() {
    if (_puzzle == null || _isLoading || _hintsUsed >= _maxHints) {
      if (_hintsUsed >= _maxHints) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No more hints!")));
      return;
    }
    final possible = <Point<int>>[];
    for (int r = 0; r < _puzzle!.size; r++) {
      for (int c = 0; c < _puzzle!.size; c++) {
        if (_userGrid[r][c] == 0 || _userGrid[r][c] != _puzzle!.solution[r][c]) {
          possible.add(Point(r, c));
        }
      }
    }
    if (possible.isNotEmpty) {
      possible.shuffle();
      final hint = possible.first;
      setState(() {
        _userGrid[hint.x][hint.y] = _puzzle!.solution[hint.x][hint.y];
        _hintsUsed++;
        _validateBoard();
        _checkForWin();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("The board is correct so far!")));
    }
  }

  void _showInstructionsDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('How to Play Futoshi'),
              content: const SingleChildScrollView(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("The goal is to place the numbers 1 to X (where X is the grid size) in each row and column, ensuring no number is repeated in any row or column."),
                  SizedBox(height: 16),
                  Text("1. No Duplicates (Latin Square)", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Each number from 1 to X must appear exactly once in each row and each column."),
                  SizedBox(height: 16),
                  Text("2. Inequality Constraints", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("If there is a '>' or '<' symbol between two cells, the numbers in those cells must obey the inequality. The arrow points to the smaller number."),
                ],
              )),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it!'))],
            ));
  }
}

class _NumberButton extends StatefulWidget {
  final int number;
  final VoidCallback onTap;

  const _NumberButton({required this.number, required this.onTap});

  @override
  State<_NumberButton> createState() => _NumberButtonState();
}

class _NumberButtonState extends State<_NumberButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
          shape: BoxShape.circle,
          boxShadow: _isPressed
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
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});
  
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
        foregroundColor: theme.colorScheme.onPrimary,
        backgroundColor: theme.colorScheme.primary.withValues(alpha:0.8),
        elevation: 3,
      ),
    );
  }
}
