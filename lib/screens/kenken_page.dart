import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'kenken_generator.dart';
import '../providers/game_provider.dart';
import '../animations/shake_animation.dart';
import '../game_state_manager.dart';
import '../win_summary_dialog.dart';
import '../models.dart';
import '../services/firebase_service.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import '../widgets/game_info_bar.dart';
import '../managers/tutorial_manager.dart';
import '../widgets/tutorial_overlay.dart';

// Top-level function for background processing
KenKenPuzzle _generatePuzzleInBackground(Map<String, int> params) {
  final int size = params['size']!;
  return KenKenGenerator(gridSize: size).generate();
}

class KenKenScreen extends StatefulWidget {
  final KenKenDifficulty difficulty;
  final int? dailyChallengeSeed;
  const KenKenScreen({super.key, required this.difficulty, this.dailyChallengeSeed});

  @override
  State<KenKenScreen> createState() => _KenKenScreenState();
}

class _KenKenScreenState extends State<KenKenScreen> with WidgetsBindingObserver {
  KenKenPuzzle? _puzzle;
  late int _gridSize;
  List<List<int>> _grid = [];

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
     WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameProvider = Provider.of<GameProvider>(context, listen: false);
      _gameProvider!.addListener(_onGameStatusChanged);
      _startNewGame().then((_) {
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

  void _onGameStatusChanged() {
    if (!mounted) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.status == GameStatus.won) {
      _handleWin();
    } else if (gameProvider.status == GameStatus.lost) {
      _showGameOverDialog();
    }
  }
  
  int _getSizeForDifficulty(KenKenDifficulty difficulty) {
    switch (difficulty) {
      case KenKenDifficulty.easy: return 4;
      case KenKenDifficulty.medium: return 5;
      case KenKenDifficulty.hard: return 6;
      case KenKenDifficulty.expert: return 7;
      case KenKenDifficulty.master: return 8;
    }
  }

  Future<void> _startNewGame() async {
    setState(() => _isLoading = true);
    _gridSize = _getSizeForDifficulty(widget.difficulty);

    final newPuzzle = await compute(_generatePuzzleInBackground, {'size': _gridSize});

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
      _grid = List.generate(_gridSize, (_) => List.generate(_gridSize, (_) => 0));
      _selectedCell = null;
      _errors = {};
      _hintsUsed = 0;
      context.read<GameProvider>().startGame();
    });
  }

   Future<void> _handleWin() async {
    _confettiController.play();
    final gameProvider = context.read<GameProvider>();
    final achievementsService = context.read<AchievementsService>();
    final timeTakenMillis = gameProvider.getElapsedMilliseconds();
    final points = (widget.difficulty.index + 1) * 100;
    
    if(isDailyChallenge){
      await GameStateManager.markDailyAsCompleted(widget.dailyChallengeSeed!);
      await FirebaseService.instance.submitDailyChallengeScore(gameName: 'KenKen', timeMillis: timeTakenMillis);
    } else {
       final stats = await GameStateManager.loadGameStats();
       final puzzlesSolved = (stats['KenKen']?.puzzlesSolved ?? 0) + 1;
       
       await GameStateManager.updateStats(gameName: 'KenKen', timeTaken: timeTakenMillis, difficulty: widget.difficulty.name);
       
       achievementsService.checkAndUnlockAchievement(AchievementId.kenkenSolved1);
       if (puzzlesSolved >= 10) {
         achievementsService.checkAndUnlockAchievement(AchievementId.kenkenSolved10);
       }
       if (widget.difficulty == KenKenDifficulty.hard) {
         achievementsService.checkAndUnlockAchievement(AchievementId.kenkenHard);
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
          onPlayAgain: isDailyChallenge ? null : () {
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

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('KenKen'),
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
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        GameInfoBar(lives: game.lives, elapsedTime: game.elapsedTime),
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

  Widget _buildGrid() {
    return KeyedSubtree(
      key: _gridKey,
      child: ShakeAnimation(
        shake: _triggerShake,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.5), width: 2.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _gridSize * _gridSize,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _gridSize),
              itemBuilder: (context, index) {
                final row = index ~/ _gridSize;
                final col = index % _gridSize;
                return _buildCell(row, col);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    if (_puzzle == null) return const SizedBox.shrink();
    final cellPoint = Point(row, col);
    final cage = _findCageForCell(cellPoint);
    final number = _grid[row][col];
    final theme = Theme.of(context);

    final isSelected = _selectedCell == cellPoint;
    final hasError = _errors.contains(cellPoint);

    bool isHighlighted = false;
    if (_selectedCell != null) {
      final selectedCage = _findCageForCell(_selectedCell!);
      if (cage == selectedCage) isHighlighted = true;
      if (_grid[_selectedCell!.x][_selectedCell!.y] != 0 && number == _grid[_selectedCell!.x][_selectedCell!.y]) isHighlighted = true;
    }

    final isTargetCell = cage.cells.first == cellPoint;
    final isSingleCellCage = cage.cells.length == 1;
    final scale = _gridSize > 5 ? 0.8 : 1.0;

    Color getCellColor() {
      if (isSelected) return theme.colorScheme.primary.withValues(alpha:0.4);
      if (isHighlighted) return theme.colorScheme.primary.withValues(alpha:0.15);
      return Colors.transparent;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedCell = cellPoint),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(color: getCellColor(), border: _getCageBorders(cellPoint, cage, theme)),
        child: Stack(
          children: [
            if (isTargetCell && !isSingleCellCage)
              Positioned(
                top: 2 * scale, left: 4 * scale,
                child: Text(cage.targetString, style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha:0.8))),
              ),
            Center(
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
                          fontSize: (32 - (_gridSize * 2.0)) * scale,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: hasError ? theme.colorScheme.error : theme.colorScheme.primary,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    if (_puzzle == null) return const SizedBox.shrink();
    int? selectedNumber;
    if (_selectedCell != null) selectedNumber = _grid[_selectedCell!.x][_selectedCell!.y];

    return KeyedSubtree(
      key: _numberPadKey,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.0, runSpacing: 8.0,
        children: List.generate(_gridSize, (index) {
          final number = index + 1;
          final isSelected = number == selectedNumber;
          return _NumberButton(
            number: number,
            isSelected: isSelected,
            onTap: () => _onNumberPressed(number),
          );
        }),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12.0,
      runSpacing: 8.0,
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
        final currentVal = _grid[_selectedCell!.x][_selectedCell!.y];
        _grid[_selectedCell!.x][_selectedCell!.y] = (currentVal == number) ? 0 : number;
        _validateBoard();
        _checkForWin();
      });
    }
  }

  void _onErasePressed() {
    if (_selectedCell != null) {
      setState(() {
        _grid[_selectedCell!.x][_selectedCell!.y] = 0;
        _validateBoard();
      });
    }
  }

  void _validateBoard() {
    if (_puzzle == null) return;
    final oldErrors = Set<Point<int>>.from(_errors);
    final newErrors = <Point<int>>{};
    
    for (int i = 0; i < _gridSize; i++) {
      final rowCounts = <int, List<int>>{};
      final colCounts = <int, List<int>>{};
      for (int j = 0; j < _gridSize; j++) {
        final rowVal = _grid[i][j];
        if (rowVal != 0) rowCounts.putIfAbsent(rowVal, () => []).add(j);
        final colVal = _grid[j][i];
        if (colVal != 0) colCounts.putIfAbsent(colVal, () => []).add(j);
      }
      for (final entry in rowCounts.entries) {
        if (entry.value.length > 1) {
          for (final col in entry.value) {
            newErrors.add(Point(i, col));
          }
        }
      }
      for (final entry in colCounts.entries) {
        if (entry.value.length > 1) {
          for (final row in entry.value) {
            newErrors.add(Point(row, i));
          }
        }
      }
    }

    for(final cage in _puzzle!.cages) {
      final values = cage.cells.map((p) => _grid[p.x][p.y]).toList();
      if (values.any((v) => v == 0)) continue;
      bool error = false;
      switch(cage.operation) {
        case KenKenOperation.add: if (values.reduce((a, b) => a + b) != cage.target) error = true; break;
        case KenKenOperation.multiply: if (values.reduce((a, b) => a * b) != cage.target) error = true; break;
        case KenKenOperation.subtract: if ((values[0] - values[1]).abs() != cage.target) error = true; break;
        case KenKenOperation.divide:
          if (values[0] == 0 || values[1] == 0 || (values[0] % values[1] != 0 && values[1] % values[0] != 0)) { 
            error = true; 
            break; 
          }
          final div = values[0] > values[1] ? values[0] / values[1] : values[1] / values[0];
          if (div.round() != cage.target) error = true;
          break;
      }
      if(error) newErrors.addAll(cage.cells);
    }

    final newlyFoundErrors = newErrors.difference(oldErrors);
    if (newlyFoundErrors.isNotEmpty) {
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
    bool isFull = !_grid.any((row) => row.any((cell) => cell == 0));
    if (isFull && _errors.isEmpty) {
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
        actions: [
          TextButton(
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

  void _showHint() {
    if (_isLoading) return;
    if (_hintsUsed >= _maxHints) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No more hints! Watch an ad to get more.")));
      return;
    }
    
    List<Point<int>> possibleHints = [];
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c] == 0 || _grid[r][c] != _puzzle!.solution[r][c]) {
          possibleHints.add(Point(r, c));
        }
      }
    }
    if (possibleHints.isNotEmpty) {
      possibleHints.shuffle();
      final hintCell = possibleHints.first;
      setState(() {
        _grid[hintCell.x][hintCell.y] = _puzzle!.solution[hintCell.x][hintCell.y];
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
        title: const Text('How to Play KenKen'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("The goal is to fill the grid with digits so that each digit appears exactly once in each row and column."),
              SizedBox(height: 16),
              Text("Rule 1: No Duplicates", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Like Sudoku, you cannot repeat a number in any row or column."),
              SizedBox(height: 16),
              Text("Rule 2: Cages", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("The numbers in each heavily outlined 'cage' must combine (in any order) to produce the target number using the specified mathematical operation (e.g., 6+, 5-, 12×, 3÷)."),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it!')),
        ],
      ),
    );
  }

  KenKenCage _findCageForCell(Point<int> cell) {
    return _puzzle!.cages.firstWhere((cage) => cage.cells.contains(cell));
  }

  Border _getCageBorders(Point<int> cell, KenKenCage cage, ThemeData theme) {
    final thin = BorderSide(color: theme.dividerColor.withValues(alpha:0.5), width: 1.0);
    final thick = BorderSide(color: theme.colorScheme.onSurface, width: 2.5);
    return Border(
      top: cage.cells.contains(Point(cell.x - 1, cell.y)) ? thin : thick,
      left: cage.cells.contains(Point(cell.x, cell.y - 1)) ? thin : thick,
      right: cage.cells.contains(Point(cell.x, cell.y + 1)) ? thin : thick,
      bottom: cage.cells.contains(Point(cell.x + 1, cell.y)) ? thin : thick,
    );
  }
  
  /// Checks if the tutorial for this game has been completed.
  void _checkTutorialStatus() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final tutorialManager = Provider.of<TutorialManager>(context, listen: false);
      if (!tutorialManager.isTutorialCompleted('KenKen')) {
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
        Provider.of<TutorialManager>(context, listen: false).completeTutorial('KenKen');
      }
    });
  }

  /// Builds the animated tutorial overlay for KenKen.
  Widget _buildTutorialOverlay() {
    String text = '';
    Alignment alignment = Alignment.center;
    Rect highlightRect = Rect.zero;

    switch (_tutorialStep) {
      case 1:
        text = 'Welcome to KenKen! Fill the grid so each number appears only once per row and column.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 2:
        text = "The numbers in each heavily outlined 'cage' must combine to make the target number using the operation shown.";
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
}

class _NumberButton extends StatefulWidget {
  final int number;
  final bool isSelected;
  final VoidCallback onTap;

  const _NumberButton({required this.number, required this.isSelected, required this.onTap});

  @override
  State<_NumberButton> createState() => _NumberButtonState();
}

class _NumberButtonState extends State<_NumberButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5);
    final fgColor = widget.isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant;
    
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
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fgColor),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});
  
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

