import 'package:flutter/material.dart';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'kakuro_generator.dart';
import '../providers/game_provider.dart';
import '../animations/shake_animation.dart';
import '../game_state_manager.dart';
import '../models/kakuro_model.dart';
import '../win_summary_dialog.dart';
import '../services/firebase_service.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import '../widgets/game_info_bar.dart';
import '../managers/tutorial_manager.dart';
import '../widgets/tutorial_overlay.dart';

// Top-level function for background generation
KakuroPuzzle _generateKakuroInBackground(Map<String, int> params) {
  final int size = params['size']!;
  return KakuroGenerator(rows: size, cols: size).generate();
}

class KakuroScreen extends StatefulWidget {
  final KakuroSize difficulty;
  final int? dailyChallengeSeed;
  const KakuroScreen({super.key, required this.difficulty, this.dailyChallengeSeed});

  @override
  State<KakuroScreen> createState() => _KakuroScreenState();
}

class _KakuroScreenState extends State<KakuroScreen> with WidgetsBindingObserver {
  KakuroPuzzle? _puzzle;
  late int _rows, _cols;
  List<List<int>> _userGrid = [];
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
    int dim = _getDimensionsFromSize(widget.difficulty);

    final newPuzzle = await compute(_generateKakuroInBackground, {'size': dim});

    if (mounted) {
      setState(() {
        _puzzle = newPuzzle;
        _rows = _puzzle!.rows;
        _cols = _puzzle!.cols;
        _restartPuzzle();
        _isLoading = false;
      });
    }
  }

  void _restartPuzzle() {
    if (_puzzle == null) return;
    setState(() {
      _userGrid = List.generate(_rows, (_) => List.generate(_cols, (_) => 0));
      _selectedCell = null;
      _errors = {};
      _hintsUsed = 0;
      context.read<GameProvider>().startGame();
    });
  }

  int _getDimensionsFromSize(KakuroSize size) {
    switch (size) {
      case KakuroSize.small: return 8;
      case KakuroSize.medium: return 10;
      case KakuroSize.large: return 13;
      case KakuroSize.expert: return 15;
      case KakuroSize.master: return 18;
    }
  }

  Future<void> _handleWin() async {
    _confettiController.play();
    final gameProvider = _gameProvider;
    if (gameProvider == null) return;

    final timeTakenMillis = gameProvider.getElapsedMilliseconds();
    final points = (widget.difficulty.index + 1) * 150;

    if (isDailyChallenge) {
      await GameStateManager.markDailyAsCompleted(widget.dailyChallengeSeed!);
      await FirebaseService.instance.submitDailyChallengeScore(gameName: 'Kakuro', timeMillis: timeTakenMillis);
    } else {
      await GameStateManager.updateStats(gameName: 'Kakuro', timeTaken: timeTakenMillis, difficulty: widget.difficulty.name);
    }

  // Safe: this is used after async work and we check `mounted` before showing UI.
  // ignore: use_build_context_synchronously
  final achievementsService = context.read<AchievementsService>();
    achievementsService.checkAndUnlockAchievement(AchievementId.kakuroSolved1);

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

  /// Checks if the tutorial for this game has been completed.
  void _checkTutorialStatus() {
    final tutorialManager = Provider.of<TutorialManager>(context, listen: false);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (!tutorialManager.isTutorialCompleted('Kakuro')) {
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
        Provider.of<TutorialManager>(context, listen: false).completeTutorial('Kakuro');
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kakuro'),
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

  /// Builds the animated tutorial overlay for Kakuro.
  Widget _buildTutorialOverlay() {
    String text = '';
    Alignment alignment = Alignment.center;
    Rect highlightRect = Rect.zero;

    switch (_tutorialStep) {
      case 1:
        text = 'Welcome to Kakuro! Fill the white cells with digits from 1-9.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 2:
        text = 'The numbers in the black cells are clues. The number on top is the sum for the column below, and the bottom number is the sum for the row to the right.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 3:
        text = 'Use the number pad to enter your answers. Remember, no number can be repeated in a single run!';
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

  Widget _buildGrid() {
    return KeyedSubtree(
      key: _gridKey,
      child: ShakeAnimation(
        shake: _triggerShake,
        child: AspectRatio(
          aspectRatio: _cols / _rows,
            child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.black.withValues(alpha:0.5), width: 2.5)),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows * _cols,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _cols),
              itemBuilder: (context, index) {
                final row = index ~/ _cols;
                final col = index % _cols;
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
    final cellData = _puzzle!.layout[row][col];
    final isSelected = _selectedCell == Point(row, col);
    final theme = Theme.of(context);

    Widget cellChild;
    if (cellData is EmptyCell) {
  cellChild = Container(color: theme.colorScheme.onSurface.withValues(alpha:0.8));
    } else if (cellData is ClueCell) {
      cellChild = _buildClueCell(cellData);
    } else if (cellData is EntryCell) {
      cellChild = _buildEntryCell(row, col, isSelected);
    } else {
      cellChild = Container(color: Colors.red);
    }

    return GestureDetector(
      onTap: cellData is EntryCell ? () => _onCellTapped(row, col) : null,
      child: Container(
  decoration: BoxDecoration(border: Border.all(color: theme.dividerColor.withValues(alpha:0.5), width: 0.5)),
        child: cellChild,
      ),
    );
  }

  Widget _buildClueCell(ClueCell cellData) {
    final theme = Theme.of(context);
    final scale = _getScale();
    return Container(
  color: theme.colorScheme.onSurface.withValues(alpha:0.8),
      child: Stack(
        children: [
          Positioned.fill(
              child: Transform.rotate(
            angle: -pi / 4,
            child: Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.surface.withValues(alpha:0.8), width: 1.5 * scale)))),
          )),
          if (cellData.colClue != null)
            Positioned(
              top: 2 * scale,
              right: 4 * scale,
              child: Text('${cellData.colClue}', style: TextStyle(color: theme.colorScheme.surface, fontWeight: FontWeight.bold, fontSize: 14 * scale)),
            ),
          if (cellData.rowClue != null)
            Positioned(
              bottom: 2 * scale,
              left: 4 * scale,
              child: Text('${cellData.rowClue}', style: TextStyle(color: theme.colorScheme.surface, fontWeight: FontWeight.bold, fontSize: 14 * scale)),
            ),
        ],
      ),
    );
  }

  Widget _buildEntryCell(int row, int col, bool isSelected) {
    final number = _userGrid[row][col];
  final theme = Theme.of(context);
    final hasError = _errors.contains(Point(row, col));
    final inSelectedRun = _isInSelectedRun(row, col);

    Color backgroundColor;
    if (isSelected) {
  backgroundColor = theme.colorScheme.primary.withValues(alpha:0.4);
    } else if (inSelectedRun) {
  backgroundColor = theme.colorScheme.primary.withValues(alpha:0.2);
    } else {
      backgroundColor = theme.canvasColor;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: backgroundColor,
  boxShadow: hasError ? [BoxShadow(color: theme.colorScheme.error.withValues(alpha:0.7), blurRadius: 4.0, spreadRadius: 1.0)] : []
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
                    fontSize: 28 * _getScale(),
                    fontWeight: FontWeight.w500,
                    color: hasError ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return KeyedSubtree(
      key: _numberPadKey,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: List.generate(9, (index) {
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

  void _onCellTapped(int row, int col) {
    setState(() => _selectedCell = Point(row, col));
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
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final cell = _puzzle!.layout[r][c];
        if (cell is ClueCell) {
          if (cell.colClue != null) _validateRun(newErrors, r + 1, c, cell.colClue!, isRow: false);
          if (cell.rowClue != null) _validateRun(newErrors, r, c + 1, cell.rowClue!, isRow: true);
        }
      }
    }

    final newlyFoundErrors = newErrors.difference(oldErrors);
    if (!isInitialLoad && newlyFoundErrors.isNotEmpty) {
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

  void _validateRun(Set<Point<int>> newErrors, int startRow, int startCol, int target, {required bool isRow}) {
    final runPoints = <Point<int>>[];
    final runValues = <int>[];
    int currentSum = 0;
    bool isFull = true;
    int r = startRow, c = startCol;
    while (true) {
      if ((isRow && (c >= _cols || _puzzle!.layout[r][c] is! EntryCell)) || (!isRow && (r >= _rows || _puzzle!.layout[r][c] is! EntryCell))) break;
      final point = Point(r, c);
      final value = _userGrid[r][c];
      runPoints.add(point);
      if (value != 0) { runValues.add(value); currentSum += value; }
      else {
        isFull = false;
      }
      if (isRow) {
        c++;
      } else {
        r++;
      }
    }
    if (runValues.toSet().length != runValues.length) newErrors.addAll(runPoints);
    if (isFull && currentSum != target) newErrors.addAll(runPoints);
  }

  void _checkForWin() {
    if (_puzzle == null) return;
    bool isGridFull = true;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (_puzzle!.layout[r][c] is EntryCell && _userGrid[r][c] == 0) {
          isGridFull = false;
          break;
        }
      }
      if (!isGridFull) break;
    }

    if (isGridFull && _errors.isEmpty) {
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
          TextButton(onPressed: () { Navigator.of(context).pop(); _startNewGame(); }, child: const Text('Try Again')),
        ],
      ),
    );
  }

  double _getScale() {
    switch(widget.difficulty) {
      case KakuroSize.small: return 1.0;
      case KakuroSize.medium: return 0.85;
      case KakuroSize.large: return 0.7;
      case KakuroSize.expert: return 0.6;
      case KakuroSize.master: return 0.5;
    }
  }

  void _showHint() {
    if (_puzzle == null || _isLoading || _hintsUsed >= _maxHints) {
      if (_hintsUsed >= _maxHints) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No more hints!")));
      }
      return;
    }

    List<Point<int>> possibleHints = [];
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (_puzzle!.layout[r][c] is EntryCell && (_userGrid[r][c] == 0 || _userGrid[r][c] != _puzzle!.solution[r][c])) {
          possibleHints.add(Point(r, c));
        }
      }
    }
    if (possibleHints.isNotEmpty) {
      possibleHints.shuffle();
      final hintCell = possibleHints.first;
      setState(() {
        _userGrid[hintCell.x][hintCell.y] = _puzzle!.solution[hintCell.x][hintCell.y];
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
        title: const Text('How to Play Kakuro'),
        content: const SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            Text("The goal is to fill the white cells with digits from 1 to 9, following the sum clues in the black cells."),
            SizedBox(height: 16),
            Text("1. Sum Clues", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("A clue above the diagonal line refers to the sum of the digits in the vertical run of white cells below it. A clue below the diagonal refers to the sum of the horizontal run to its right."),
            SizedBox(height: 16),
            Text("2. No Duplicate Digits", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Within any single run (either horizontal or vertical), you cannot use the same digit more than once."),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it!'))],
      ),
    );
  }

  bool _isInSelectedRun(int row, int col) {
    if (_selectedCell == null || _puzzle == null) return false;
    if (row == _selectedCell!.x) {
      int c = col; while (c >= 0 && _puzzle!.layout[row][c] is EntryCell) {
        c--;
      }
      int startCol = c + 1;
      c = col; while (c < _cols && _puzzle!.layout[row][c] is EntryCell) {
        c++;
      }
      int endCol = c - 1;
      if (_selectedCell!.y >= startCol && _selectedCell!.y <= endCol) return true;
    }
    if (col == _selectedCell!.y) {
      int r = row; while (r >= 0 && _puzzle!.layout[r][col] is EntryCell) {
        r--;
      }
      int startRow = r + 1;
      r = row; while (r < _rows && _puzzle!.layout[r][col] is EntryCell) {
        r++;
      }
      int endRow = r - 1;
      if (_selectedCell!.x >= startRow && _selectedCell!.x <= endRow) return true;
    }
    return false;
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
  final bool isSelected;
  
  const _ActionButton({required this.icon, required this.label, this.onTap, bool selected = false}) : isSelected = selected;
  
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
