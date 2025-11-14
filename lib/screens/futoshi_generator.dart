import 'dart:math';
import 'futoshi_page.dart';

/// A class to generate new Futoshi puzzles.
class FutoshiGenerator {
  final int size;
  final int difficulty; // e.g., number of constraints

  late List<List<int>> _solution;
  late List<FutoshiConstraint> _constraints;

  FutoshiGenerator({required this.size, this.difficulty = 0});

  FutoshiPuzzle generate() {
    _createSolution();
    _createConstraints();

    // Create a copy of the solution to include in the puzzle object
    final List<List<int>> solutionCopy = List.generate(size, (r) => List<int>.from(_solution[r]));

    return FutoshiPuzzle(
      size: size,
      initialGrid: _createInitialGrid(),
      constraints: _constraints,
      solution: solutionCopy, // Add the solution for the hint system
    );
  }

  /// Creates a valid Latin Square solution.
  void _createSolution() {
    _solution = List.generate(size, (_) => List.filled(size, 0));
    _fillCell(0, 0);
  }

  /// Recursive backtracking function to fill the grid.
  bool _fillCell(int r, int c) {
    if (r == size) {
      return true; // Grid is successfully filled
    }

    int nextR = (c == size - 1) ? r + 1 : r;
    int nextC = (c == size - 1) ? 0 : c + 1;

    final numbers = List.generate(size, (i) => i + 1)..shuffle();

    for (int num in numbers) {
      if (_isSafe(r, c, num)) {
        _solution[r][c] = num;
        if (_fillCell(nextR, nextC)) {
          return true;
        }
        _solution[r][c] = 0; // Backtrack
      }
    }
    return false;
  }

  /// Checks if a number can be placed in a cell without row/col conflicts.
  bool _isSafe(int r, int c, int num) {
    for (int i = 0; i < size; i++) {
      if (_solution[r][i] == num || _solution[i][c] == num) {
        return false;
      }
    }
    return true;
  }

  /// Creates inequality constraints based on the solution.
  void _createConstraints() {
    _constraints = [];
    final rand = Random();
    final numConstraints = difficulty > 0 ? difficulty : (size * size) ~/ 4;

    while (_constraints.length < numConstraints) {
      final r = rand.nextInt(size);
      final c = rand.nextInt(size);
      final isHorizontal = rand.nextBool();

      if (isHorizontal && c < size - 1) {
        final p1 = Point(r, c);
        final p2 = Point(r, c + 1);
        if (_solution[r][c] > _solution[r][c + 1]) {
          _addConstraint(FutoshiConstraint(from: p1, to: p2));
        } else {
          _addConstraint(FutoshiConstraint(from: p2, to: p1));
        }
      } else if (!isHorizontal && r < size - 1) {
        final p1 = Point(r, c);
        final p2 = Point(r + 1, c);
        if (_solution[r][c] > _solution[r + 1][c]) {
          _addConstraint(FutoshiConstraint(from: p1, to: p2));
        } else {
          _addConstraint(FutoshiConstraint(from: p2, to: p1));
        }
      }
    }
  }

  /// Adds a constraint if it doesn't already exist.
  void _addConstraint(FutoshiConstraint newConstraint) {
    bool exists = _constraints.any((c) =>
    (c.from == newConstraint.from && c.to == newConstraint.to) ||
        (c.from == newConstraint.to && c.to == newConstraint.from));
    if (!exists) {
      _constraints.add(newConstraint);
    }
  }

  /// Creates the initial puzzle grid by removing numbers.
  List<List<int>> _createInitialGrid() {
    // For now, we'll start with a completely empty grid.
    return List.generate(size, (_) => List.filled(size, 0));
  }
}
