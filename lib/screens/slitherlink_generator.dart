import 'dart:math';
import '../models.dart';

/// A class to generate new Slitherlink puzzles.
class SlitherlinkGenerator {
  final int rows;
  final int cols;

  late List<List<bool>> _horizontalLines;
  late List<List<bool>> _verticalLines;
  late List<List<bool>> _visitedDots;

  SlitherlinkGenerator({required this.rows, required this.cols});

  SlitherlinkPuzzle generate() {
    _generateLoop();
    final clues = _calculateClues();

    // Create a copy of the solution before removing clues for the hint system
    final List<List<bool>> solutionH = List.generate(rows + 1, (r) => List<bool>.from(_horizontalLines[r]));
    final List<List<bool>> solutionV = List.generate(rows, (r) => List<bool>.from(_verticalLines[r]));

    _removeClues(clues);

    return SlitherlinkPuzzle(
      rows: rows,
      cols: cols,
      clues: clues,
      solutionHorizontalLines: solutionH,
      solutionVerticalLines: solutionV,
    );
  }

  /// Generates a single, non-intersecting loop.
  void _generateLoop() {
    final rand = Random();
    int attempts = 0;
    while (attempts < 1000) { // Limit attempts to prevent infinite loops
      _horizontalLines = List.generate(rows + 1, (_) => List.filled(cols, false));
      _verticalLines = List.generate(rows, (_) => List.filled(cols + 1, false));
      _visitedDots = List.generate(rows + 1, (_) => List.filled(cols + 1, false));

      final startR = rand.nextInt(rows + 1);
      final startC = rand.nextInt(cols + 1);

      if (_findLoop(startR, startC, startR, startC, 1)) {
        int lineCount = 0;
        for (final row in _horizontalLines) {
          for (final line in row) {
            if (line) lineCount++;
          }
        }
        for (final row in _verticalLines) {
          for (final line in row) {
            if (line) lineCount++;
          }
        }

        if (lineCount > (rows + cols)) return; // Found a reasonably complex loop
      }
      attempts++;
    }
    _createFallbackLoop(); // Use a simple loop if generation fails
  }

  /// Fallback to a simple rectangular loop if the generator fails.
  void _createFallbackLoop() {
    _horizontalLines = List.generate(rows + 1, (_) => List.filled(cols, false));
    _verticalLines = List.generate(rows, (_) => List.filled(cols + 1, false));
    for (int c = 0; c < cols; c++) {
      _horizontalLines[0][c] = true;
      _horizontalLines[rows][c] = true;
    }
    for (int r = 0; r < rows; r++) {
      _verticalLines[r][0] = true;
      _verticalLines[r][cols] = true;
    }
  }

  /// Recursive backtracking function to create a loop path.
  bool _findLoop(int r, int c, int startR, int startC, int steps) {
    if (r == startR && c == startC && steps > 4) {
      return true; // Loop is complete
    }
    if (_visitedDots[r][c]) {
      return false; // Path has crossed itself
    }
    _visitedDots[r][c] = true;

    final directions = [[-1, 0], [1, 0], [0, -1], [0, 1]]..shuffle();

    for (final dir in directions) {
      final nextR = r + dir[0];
      final nextC = c + dir[1];

      if (nextR >= 0 && nextR <= rows && nextC >= 0 && nextC <= cols) {
        if (dir[0] != 0) { // Vertical move
          _verticalLines[min(r, nextR)][c] = true;
        } else { // Horizontal move
          _horizontalLines[r][min(c, nextC)] = true;
        }

        if (_findLoop(nextR, nextC, startR, startC, steps + 1)) {
          return true;
        }

        // Backtrack
        if (dir[0] != 0) {
          _verticalLines[min(r, nextR)][c] = false;
        } else {
          _horizontalLines[r][min(c, nextC)] = false;
        }
      }
    }
    _visitedDots[r][c] = false;
    return false;
  }

  /// Calculates clues based on the final loop solution.
  List<List<int?>> _calculateClues() {
    var clues = List.generate(rows, (_) => List<int?>.filled(cols, null));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int count = 0;
        if (_horizontalLines[r][c]) count++;
        if (_horizontalLines[r + 1][c]) count++;
        if (_verticalLines[r][c]) count++;
        if (_verticalLines[r][c + 1]) count++;
        clues[r][c] = count;
      }
    }
    return clues;
  }

  /// Removes clues to create the puzzle, leaving some for the player.
  void _removeClues(List<List<int?>> clues) {
    final rand = Random();
    int cluesToRemove = (rows * cols * 0.65).toInt();
    for (int i = 0; i < cluesToRemove; i++) {
      clues[rand.nextInt(rows)][rand.nextInt(cols)] = null;
    }
  }
}
