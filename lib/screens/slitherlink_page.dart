import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'slitherlink_generator.dart';
import '../providers/game_provider.dart';
import '../animations/shake_animation.dart';
import '../game_state_manager.dart';
import '../services/firebase_service.dart';
import '../win_summary_dialog.dart';
import '../models.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import '../widgets/game_info_bar.dart';
import '../managers/tutorial_manager.dart';
import '../widgets/tutorial_overlay.dart';


// --- Top-level function for background processing ---
SlitherlinkPuzzle _generatePuzzleInBackground(Map<String, int> params) {
  final int size = params['size']!;
  return SlitherlinkGenerator(rows: size, cols: size).generate();
}

class SlitherlinkScreen extends StatefulWidget {
  final SlitherlinkDifficulty difficulty;
  final int? dailyChallengeSeed;
  const SlitherlinkScreen({super.key, required this.difficulty, this.dailyChallengeSeed});

  @override
  State<SlitherlinkScreen> createState() => _SlitherlinkScreenState();
}

class _SlitherlinkScreenState extends State<SlitherlinkScreen> with WidgetsBindingObserver {
  // --- Game State ---
  SlitherlinkPuzzle? _puzzle;
  late List<List<LineState>> _horizontalLines;
  late List<List<LineState>> _verticalLines;
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
    _confettiController.dispose();
    WidgetsBinding.instance.removeObserver(this);
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

  // --- Game Setup ---
  int _getSizeForDifficulty(SlitherlinkDifficulty difficulty) {
    switch (difficulty) {
      case SlitherlinkDifficulty.easy: return 5;
      case SlitherlinkDifficulty.medium: return 7;
      case SlitherlinkDifficulty.hard: return 9;
      case SlitherlinkDifficulty.expert: return 10;
      case SlitherlinkDifficulty.master: return 12;
    }
  }

  Future<void> _startNewGame() async {
    setState(() => _isLoading = true);
    final size = _getSizeForDifficulty(widget.difficulty);
    final newPuzzle = await compute(_generatePuzzleInBackground, {'size': size});

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
      _horizontalLines = List.generate(_puzzle!.rows + 1, (_) => List.filled(_puzzle!.cols, LineState.empty));
      _verticalLines = List.generate(_puzzle!.rows, (_) => List.filled(_puzzle!.cols + 1, LineState.empty));
      _errors = {};
      _hintsUsed = 0;
      _validateBoard();
      context.read<GameProvider>().startGame();
    });
  }

  Future<void> _handleWin() async {
    _confettiController.play();
    final gameProvider = context.read<GameProvider>();
    final timeTakenMillis = gameProvider.getElapsedMilliseconds();
    final points = (widget.difficulty.index + 1) * 150;
    final achievementsService = Provider.of<AchievementsService>(context, listen: false);

    if (isDailyChallenge) {
      await GameStateManager.markDailyAsCompleted(widget.dailyChallengeSeed!);
      await FirebaseService.instance.submitDailyChallengeScore(gameName: 'Slitherlink', timeMillis: timeTakenMillis);
    } else {
       await GameStateManager.updateStats(gameName: 'Slitherlink', timeTaken: timeTakenMillis, difficulty: widget.difficulty.name);
    }

    achievementsService.checkAndUnlockAchievement(AchievementId.slitherlinkSolved1);

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
      if (!tutorialManager.isTutorialCompleted('Slitherlink')) {
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
        Provider.of<TutorialManager>(context, listen: false).completeTutorial('Slitherlink');
      }
    });
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slitherlink'),
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
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _puzzle?.cols != null && _puzzle?.rows != null ? _puzzle!.cols / _puzzle!.rows : 1.0,
                              child: _buildGameBoard(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
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

  /// Builds the animated tutorial overlay for Slitherlink.
  Widget _buildTutorialOverlay() {
    String text = '';
    Alignment alignment = Alignment.center;
    Rect highlightRect = Rect.zero;

    switch (_tutorialStep) {
      case 1:
        text = 'Welcome to Slitherlink! Tap between the dots to draw a single, continuous loop.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
        break;
      case 2:
        text = 'The numbers tell you how many sides of that square are part of the loop. Tap a line again to mark it with an X, or a third time to clear it.';
        alignment = Alignment.center;
        highlightRect = _getWidgetRect(_gridKey);
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
        child: GestureDetector(
          onTapUp: (details) {
            HapticFeedback.lightImpact();
            _handleTap(details.localPosition);
          },
          child: CustomPaint(
            painter: SlitherlinkPainter(
              puzzle: _puzzle!,
              horizontalLines: _horizontalLines,
              verticalLines: _verticalLines,
              errors: _errors,
              theme: Theme.of(context),
            ),
            child: Container(),
          ),
        ),
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

  // --- Game Logic ---
  void _handleTap(Offset localPosition) {
    if (_isLoading || _puzzle == null) return;
    final Size size = (context.findRenderObject() as RenderBox).size;
    final double cellWidth = size.width / _puzzle!.cols;
    final double cellHeight = size.height / _puzzle!.rows;
    const double tapTolerance = 0.3;

    for (int r = 0; r < _puzzle!.rows + 1; r++) {
      for (int c = 0; c < _puzzle!.cols; c++) {
        final y = r * cellHeight;
        final x1 = c * cellWidth;
        final x2 = (c + 1) * cellWidth;
        if (localPosition.dy > y - cellHeight * tapTolerance && localPosition.dy < y + cellHeight * tapTolerance && localPosition.dx > x1 && localPosition.dx < x2) {
          setState(() {
            _horizontalLines[r][c] = _cycleState(_horizontalLines[r][c]);
            _validateBoard();
            _checkForWin();
          });
          return;
        }
      }
    }
    for (int r = 0; r < _puzzle!.rows; r++) {
      for (int c = 0; c < _puzzle!.cols + 1; c++) {
        final x = c * cellWidth;
        final y1 = r * cellHeight;
        final y2 = (r + 1) * cellHeight;
        if (localPosition.dx > x - cellWidth * tapTolerance && localPosition.dx < x + cellWidth * tapTolerance && localPosition.dy > y1 && localPosition.dy < y2) {
          setState(() {
            _verticalLines[r][c] = _cycleState(_verticalLines[r][c]);
            _validateBoard();
            _checkForWin();
          });
          return;
        }
      }
    }
  }

  LineState _cycleState(LineState currentState) {
    switch (currentState) {
      case LineState.empty:
        return LineState.line;
      case LineState.line:
        return LineState.markedEmpty;
      case LineState.markedEmpty:
        return LineState.empty;
    }
  }

  void _validateBoard() {
    if (_puzzle == null) return;
    final oldErrors = Set<Point<int>>.from(_errors);
    final newErrors = <Point<int>>{};
    for (int r = 0; r < _puzzle!.rows; r++) {
      for (int c = 0; c < _puzzle!.cols; c++) {
        final clue = _puzzle!.clues[r][c];
        if (clue != null) {
          int surroundingLines = 0;
          if (_horizontalLines[r][c] == LineState.line) surroundingLines++;
          if (_horizontalLines[r + 1][c] == LineState.line) surroundingLines++;
          if (_verticalLines[r][c] == LineState.line) surroundingLines++;
          if (_verticalLines[r][c + 1] == LineState.line) surroundingLines++;

          bool anyEmpty = _horizontalLines[r][c] == LineState.empty || _horizontalLines[r + 1][c] == LineState.empty || _verticalLines[r][c] == LineState.empty || _verticalLines[r][c + 1] == LineState.empty;

          if (!anyEmpty && surroundingLines != clue) {
            newErrors.add(Point(r, c));
          }
        }
      }
    }

    final newlyFoundErrors = newErrors.difference(oldErrors);
    if (newlyFoundErrors.isNotEmpty) {
      _handleMistake();
    }
    setState(() {
      _errors = newErrors;
    });
  }

  void _handleMistake() {
    context.read<GameProvider>().handleMistake();
    setState(() {
      _triggerShake = true;
      Future.delayed(const Duration(milliseconds: 500), () => setState(() => _triggerShake = false));
    });
  }

  Future<void> _checkForWin() async {
    if (_puzzle == null) return;
    bool allCluesMet = true;
    for (int r = 0; r < _puzzle!.rows; r++) {
      for (int c = 0; c < _puzzle!.cols; c++) {
        final clue = _puzzle!.clues[r][c];
        if (clue != null) {
          int surroundingLines = 0;
          if (_horizontalLines[r][c] == LineState.line) surroundingLines++;
          if (_horizontalLines[r + 1][c] == LineState.line) surroundingLines++;
          if (_verticalLines[r][c] == LineState.line) surroundingLines++;
          if (_verticalLines[r][c + 1] == LineState.line) surroundingLines++;
          if (surroundingLines != clue) {
            allCluesMet = false;
            break;
          }
        }
      }
      if (!allCluesMet) break;
    }

    if (allCluesMet) {
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
    if (_puzzle == null || _isLoading || _hintsUsed >= _maxHints) {
      if (_hintsUsed >= _maxHints) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No more hints!")));
      }
      return;
    }

    List<Function> possibleHints = [];

    for (int r = 0; r < _puzzle!.solutionHorizontalLines.length; r++) {
      for (int c = 0; c < _puzzle!.solutionHorizontalLines[r].length; c++) {
        if (_puzzle!.solutionHorizontalLines[r][c] && _horizontalLines[r][c] != LineState.line) {
          possibleHints.add(() => setState(() => _horizontalLines[r][c] = LineState.line));
        }
      }
    }
    for (int r = 0; r < _puzzle!.solutionVerticalLines.length; r++) {
      for (int c = 0; c < _puzzle!.solutionVerticalLines[r].length; c++) {
        if (_puzzle!.solutionVerticalLines[r][c] && _verticalLines[r][c] != LineState.line) {
          possibleHints.add(() => setState(() => _verticalLines[r][c] = LineState.line));
        }
      }
    }

    if (possibleHints.isNotEmpty) {
      possibleHints.shuffle();
      possibleHints.first(); 
      setState(() {
        _hintsUsed++;
      });
      _validateBoard();
      _checkForWin();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("The board is correct so far!")));
    }
  }

  void _showInstructionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play Slitherlink'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("The goal is to connect the dots to form a single, continuous loop with no crossings or branches."),
              SizedBox(height: 16),
              Text("1. Number Clues", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Each number indicates how many of the four sides of its cell are part of the loop."),
              SizedBox(height: 16),
              Text("2. One Loop", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("The lines must form a single, unbroken loop. You cannot have multiple separate loops."),
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

// --- Custom Painter for the Game Board ---
class SlitherlinkPainter extends CustomPainter {
  final SlitherlinkPuzzle puzzle;
  final List<List<LineState>>? horizontalLines;
  final List<List<LineState>>? verticalLines;
  final Set<Point<int>> errors;
  final ThemeData theme;

  SlitherlinkPainter({
    required this.puzzle,
    this.horizontalLines,
    this.verticalLines,
    required this.errors,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / puzzle.cols;
    final double cellHeight = size.height / puzzle.rows;
    final dotPaint = Paint()..color = theme.colorScheme.onSurface.withValues(alpha:0.3);
    final linePaint = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final xPaint = Paint()
      ..color = theme.disabledColor.withValues(alpha:0.7)
      ..strokeWidth = 2.0;
    final scale = puzzle.rows > 7 ? 0.8 : 1.0;

    for (int r = 0; r < puzzle.rows; r++) {
      for (int c = 0; c < puzzle.cols; c++) {
        final clue = puzzle.clues[r][c];
        if (clue != null) {
          final isError = errors.contains(Point(r, c));
          final textSpan = TextSpan(
            text: '$clue',
            style: TextStyle(
              color: isError ? theme.colorScheme.error : theme.colorScheme.onSurface,
              fontSize: 24 * scale,
              fontWeight: FontWeight.bold,
            ),
          );
          final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
          final offset = Offset(c * cellWidth + (cellWidth / 2 - textPainter.width / 2), r * cellHeight + (cellHeight / 2 - textPainter.height / 2));
          textPainter.paint(canvas, offset);
        }
      }
    }
    if (horizontalLines != null) {
      for (int r = 0; r < puzzle.rows + 1; r++) {
        for (int c = 0; c < puzzle.cols; c++) {
          final p1 = Offset(c * cellWidth, r * cellHeight);
          final p2 = Offset((c + 1) * cellWidth, r * cellHeight);
          if (horizontalLines![r][c] == LineState.line) {
            canvas.drawLine(p1.translate(cellWidth * 0.1, 0), p2.translate(-cellWidth * 0.1, 0), linePaint);
          } else if (horizontalLines![r][c] == LineState.markedEmpty) {
            final center = (p1 + p2) / 2;
            canvas.drawLine(center.translate(-4, -4), center.translate(4, 4), xPaint);
            canvas.drawLine(center.translate(4, -4), center.translate(-4, 4), xPaint);
          }
        }
      }
    }
    if (verticalLines != null) {
      for (int r = 0; r < puzzle.rows; r++) {
        for (int c = 0; c < puzzle.cols + 1; c++) {
          final p1 = Offset(c * cellWidth, r * cellHeight);
          final p2 = Offset(c * cellWidth, (r + 1) * cellHeight);
          if (verticalLines![r][c] == LineState.line) {
            canvas.drawLine(p1.translate(0, cellHeight * 0.1), p2.translate(0, -cellHeight * 0.1), linePaint);
          } else if (verticalLines![r][c] == LineState.markedEmpty) {
            final center = (p1 + p2) / 2;
            canvas.drawLine(center.translate(-4, -4), center.translate(4, 4), xPaint);
            canvas.drawLine(center.translate(4, -4), center.translate(-4, 4), xPaint);
          }
        }
      }
    }
    for (int r = 0; r < puzzle.rows + 1; r++) {
      for (int c = 0; c < puzzle.cols + 1; c++) {
        canvas.drawCircle(Offset(c * cellWidth, r * cellHeight), 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
