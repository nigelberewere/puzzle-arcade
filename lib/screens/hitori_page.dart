import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:collection';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'hitori_generator.dart';
import '../providers/game_provider.dart';
import '../animations/shake_animation.dart';
import '../game_state_manager.dart';
import '../models/hitori_model.dart';
import '../win_summary_dialog.dart';
import '../services/firebase_service.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import '../widgets/game_info_bar.dart';
import '../managers/tutorial_manager.dart';
import '../widgets/tutorial_overlay.dart';

// Top-level function for background generation
HitoriPuzzle _generateHitoriInBackground(Map<String, int> params) {
  final int size = params['size']!;
  return HitoriGenerator(gridSize: size).generate();
}

class HitoriScreen extends StatefulWidget {
  final HitoriDifficulty difficulty;
  final int? dailyChallengeSeed;
  const HitoriScreen({super.key, required this.difficulty, this.dailyChallengeSeed});

  @override
  State<HitoriScreen> createState() => _HitoriScreenState();
}

class _HitoriScreenState extends State<HitoriScreen> with WidgetsBindingObserver {
  HitoriPuzzle? _puzzle;
  late int _gridSize;
  List<List<HitoriCellState>> _userState = [];
  Set<Point<int>> _errors = {};
  bool _isShadingMode = true;
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
  final GlobalKey _toggleKey = GlobalKey();

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
    _gridSize = _getSizeForDifficulty(widget.difficulty);

    final newPuzzle = await compute(_generateHitoriInBackground, {'size': _gridSize});

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
      _userState = List.generate(_gridSize, (_) => List.generate(_gridSize, (_) => HitoriCellState.normal));
      _isShadingMode = true;
      _errors = {};
      _hintsUsed = 0;
      context.read<GameProvider>().startGame();
    });
  }
  
  int _getSizeForDifficulty(HitoriDifficulty difficulty) {
    switch (difficulty) {
      case HitoriDifficulty.easy: return 5;
      case HitoriDifficulty.medium: return 7;
      case HitoriDifficulty.hard: return 9;
      case HitoriDifficulty.expert: return 10;
      case HitoriDifficulty.master: return 12;
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
      await FirebaseService.instance.submitDailyChallengeScore(gameName: 'Hitori', timeMillis: timeTakenMillis);
    } else {
      await GameStateManager.updateStats(gameName: 'Hitori', timeTaken: timeTakenMillis, difficulty: widget.difficulty.name);
    }
    
    achievementsService.checkAndUnlockAchievement(AchievementId.hitoriSolved1);

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

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hitori'),
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
                        _buildModeToggle(),
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
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.3), width: 2.5),
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
    final state = _userState[row][col];
    final number = _puzzle!.puzzle[row][col];
    final theme = Theme.of(context);
    final hasError = _errors.contains(Point(row, col));
    
    Color textColor;
    Widget backgroundWidget;

    switch (state) {
      case HitoriCellState.shaded:
        textColor = theme.colorScheme.surface;
        backgroundWidget = Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha:0.9),
            borderRadius: BorderRadius.circular(4)
          ),
        );
        break;
      case HitoriCellState.circled:
        textColor = theme.colorScheme.secondary;
        backgroundWidget = Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.secondary, width: 2.5),
            shape: BoxShape.circle,
          ),
        );
        break;
      case HitoriCellState.normal:
        textColor = theme.colorScheme.onSurface;
        backgroundWidget = const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); _onCellTapped(row, col); },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withValues(alpha:0.5), width: 0.5)
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: backgroundWidget,
            ),
             if (hasError) 
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha:0.5),
                  borderRadius: BorderRadius.circular(4)
                ),
              ),
            Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 28 - (_gridSize * 1.5),
                  fontWeight: FontWeight.bold,
                  color: hasError ? theme.colorScheme.onError : textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return KeyedSubtree(
      key: _toggleKey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           _ActionButton(
            icon: Icons.edit,
            label: 'Shade',
            onTap: () => setState(() => _isShadingMode = true),
            isSelected: _isShadingMode,
          ),
          const SizedBox(width: 12),
          _ActionButton(
            icon: Icons.circle_outlined,
            label: 'Circle',
            onTap: () => setState(() => _isShadingMode = false),
            isSelected: !_isShadingMode,
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

  void _onCellTapped(int row, int col) {
    setState(() {
      final currentState = _userState[row][col];
      if (_isShadingMode) {
        _userState[row][col] = currentState == HitoriCellState.shaded ? HitoriCellState.normal : HitoriCellState.shaded;
      } else {
        _userState[row][col] = currentState == HitoriCellState.circled ? HitoriCellState.normal : HitoriCellState.circled;
      }
      _validateBoard();
      _checkForWin();
    });
  }

  void _validateBoard({bool isInitialLoad = false}) {
    if (_puzzle == null) return;
    final oldErrors = Set<Point<int>>.from(_errors);
    final newErrors = <Point<int>>{};
    
    for (int i = 0; i < _gridSize; i++) {
      _findDuplicatesInLine(newErrors, isRow: true, index: i);
      _findDuplicatesInLine(newErrors, isRow: false, index: i);
    }
    _checkConnectivityAndAdjacency(newErrors);

    final newlyFoundErrors = newErrors.difference(oldErrors);
    if (!isInitialLoad && newlyFoundErrors.isNotEmpty) {
      _handleMistake();
    }
    setState(() => _errors = newErrors);
  }

  void _findDuplicatesInLine(Set<Point<int>> newErrors, {required bool isRow, required int index}) {
    final seen = <int, List<Point<int>>>{};
    for (int j = 0; j < _gridSize; j++) {
      final row = isRow ? index : j, col = isRow ? j : index;
      if (_userState[row][col] != HitoriCellState.shaded) {
        final number = _puzzle!.puzzle[row][col];
        seen.putIfAbsent(number, () => []).add(Point(row, col));
      }
    }
    for (final entry in seen.entries) {
      if (entry.value.length > 1) newErrors.addAll(entry.value);
    }
  }

  void _checkConnectivityAndAdjacency(Set<Point<int>> newErrors) {
    Point<int>? firstUnshaded;
    int unshadedCount = 0;
    final visited = <Point<int>>{};
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        final point = Point(r, c);
        if (_userState[r][c] == HitoriCellState.shaded) {
          for (final neighbor in _getNeighbors(r, c)) {
            if (_userState[neighbor.x][neighbor.y] == HitoriCellState.shaded) {
              newErrors.add(point); newErrors.add(neighbor);
            }
          }
        } else {
          unshadedCount++;
          firstUnshaded ??= point;
        }
      }
    }
    if (firstUnshaded != null) {
      final queue = Queue<Point<int>>()..add(firstUnshaded);
      visited.add(firstUnshaded);
      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        for (final neighbor in _getNeighbors(current.x, current.y)) {
          if (_userState[neighbor.x][neighbor.y] != HitoriCellState.shaded && !visited.contains(neighbor)) {
            visited.add(neighbor); queue.add(neighbor);
          }
        }
      }
      if (visited.length != unshadedCount) {
        for (int r = 0; r < _gridSize; r++) {
          for (int c = 0; c < _gridSize; c++) {
            final point = Point(r, c);
            if(_userState[r][c] != HitoriCellState.shaded && !visited.contains(point)) {
              newErrors.add(point);
            }
          }
        }
      }
    }
  }

  void _handleMistake() {
    context.read<GameProvider>().handleMistake();
    setState(() {
      _triggerShake = true;
      Future.delayed(const Duration(milliseconds: 500), () => setState(() => _triggerShake = false));
    });
  }

  void _checkForWin() {
    bool hasShadedCells = _userState.any((row) => row.contains(HitoriCellState.shaded));
    if (hasShadedCells && _errors.isEmpty) {
      context.read<GameProvider>().winGame();
    }
  }

  void _showGameOverDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
      title: const Text('Game Over'),
      content: const Text('You have run out of lives!'),
      actions: [TextButton(onPressed: () { Navigator.of(context).pop(); _restartPuzzle(); }, child: const Text('Try Again'))],
    ));
  }

  void _showHint() {
    if (_puzzle == null || _isLoading || _hintsUsed >= _maxHints) {
      if(_hintsUsed >= _maxHints) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No more hints!")));
      return;
    }
    List<Point<int>> possibleHints = [];
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        final isShaded = _puzzle!.isShaded[r][c];
        final userState = _userState[r][c];
        if ((isShaded && userState != HitoriCellState.shaded) || (!isShaded && userState == HitoriCellState.shaded)) {
          possibleHints.add(Point(r,c));
        }
      }
    }
    if (possibleHints.isNotEmpty) {
      possibleHints.shuffle();
      final hintCell = possibleHints.first;
      setState(() {
        if (_puzzle!.isShaded[hintCell.x][hintCell.y]) {
          _userState[hintCell.x][hintCell.y] = HitoriCellState.shaded;
        } else {
          _userState[hintCell.x][hintCell.y] = HitoriCellState.circled;
        }
        _hintsUsed++;
        _validateBoard();
        _checkForWin();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("The board is correct so far!")));
    }
  }

  void _showInstructionsDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('How to Play Hitori'),
      content: const SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          Text("The goal is to shade out cells until three rules are satisfied."),
          SizedBox(height: 16),
          Text("1. No Duplicates in Rows/Columns", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("No number can appear more than once in any row or column among the un-shaded (white) cells."),
          SizedBox(height: 16),
          Text("2. No Adjacent Shaded Cells", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("Shaded (black) cells cannot touch each other vertically or horizontally."),
          SizedBox(height: 16),
          Text("3. All White Cells are Connected", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("All the un-shaded (white) cells must form a single, continuous area connected vertically and horizontally."),
        ],
      )),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it!'))],
    ));
  }

  List<Point<int>> _getNeighbors(int r, int c) {
    final neighbors = <Point<int>>[];
    if (r > 0) neighbors.add(Point(r - 1, c));
    if (r < _gridSize - 1) neighbors.add(Point(r + 1, c));
    if (c > 0) neighbors.add(Point(r, c - 1));
    if (c < _gridSize - 1) neighbors.add(Point(r, c + 1));
    return neighbors;
  }
  
  /// Checks if the tutorial for this game has been completed.
  void _checkTutorialStatus() {
     Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final tutorialManager = Provider.of<TutorialManager>(context, listen: false);
      if (!tutorialManager.isTutorialCompleted('Hitori')) {
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
        Provider.of<TutorialManager>(context, listen: false).completeTutorial('Hitori');
      }
    });
  }

  /// Builds the animated tutorial overlay for Hitori.
  Widget _buildTutorialOverlay() {
    String text = '';
    Alignment alignment = Alignment.center;
    Rect highlightRect = Rect.zero;

    switch (_tutorialStep) {
      case 1:
        text = 'Welcome to Hitori! Shade cells so no number appears more than once in any row or column.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 2:
        text = 'Shaded cells cannot be adjacent, and all unshaded cells must form a single connected group.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 3:
        text = 'Use these buttons to switch between shading cells or circling cells you know are safe.';
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

