import 'dart:math';

/// Defines the logical techniques used to solve a Sudoku.
/// The order represents increasing difficulty.
enum SudokuTechnique {
  nakedSingle,
  hiddenSingle,
  // More techniques like Naked Pairs, X-Wing, etc., could be added here.
  // For this example, we'll focus on singles.
  ambiguous, // Puzzle requires guessing (has multiple solutions or is too hard)
  unsolvable, // Puzzle has no solution
}

/// Represents a step taken by the logical solver.
class SolveStep {
  final Point<int> cell;
  final int value;
  final SudokuTechnique technique;

  SolveStep(this.cell, this.value, this.technique);
}

/// A logical Sudoku solver that can determine the difficulty of a puzzle.
class SudokuSolver {
  late List<List<int>> _grid;
  late List<List<Set<int>>> _candidates;

  /// Analyzes a puzzle and returns the most difficult technique required to solve it.
  SudokuTechnique rateDifficulty(List<List<int>> puzzle) {
    if (!hasUniqueSolution(puzzle)) {
      return SudokuTechnique.ambiguous;
    }

    _initialize(puzzle);
    SudokuTechnique maxDifficulty = SudokuTechnique.nakedSingle;

    bool changed;
    do {
      changed = false;
      final step = _findNextMove();

      if (step != null) {
        if (step.technique.index > maxDifficulty.index) {
          maxDifficulty = step.technique;
        }
        _applyMove(step);
        changed = true;
      }
    } while (changed);

    if (!_isSolved()) {
      // If not solved, it requires techniques not yet implemented.
      // For this example, we'll classify it as ambiguous.
      return SudokuTechnique.ambiguous;
    }

    return maxDifficulty;
  }

  /// Checks if a puzzle has exactly one solution.
  bool hasUniqueSolution(List<List<int>> puzzle) {
    int solutionCount = 0;
    _solveBruteForce(List.generate(9, (r) => List.from(puzzle[r])), (grid) {
      solutionCount++;
    }, stopAfter: 2);
    return solutionCount == 1;
  }

  void _initialize(List<List<int>> puzzle) {
    _grid = List.generate(9, (r) => List.from(puzzle[r]));
    _candidates = List.generate(9, (_) => List.generate(9, (_) => {1, 2, 3, 4, 5, 6, 7, 8, 9}));

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_grid[r][c] != 0) {
          _candidates[r][c].clear();
          _updatePeers(r, c, _grid[r][c]);
        }
      }
    }
  }

  void _applyMove(SolveStep step) {
    _grid[step.cell.x][step.cell.y] = step.value;
    _candidates[step.cell.x][step.cell.y].clear();
    _updatePeers(step.cell.x, step.cell.y, step.value);
  }

  void _updatePeers(int r, int c, int value) {
    // Row
    for (int i = 0; i < 9; i++) {
      _candidates[r][i].remove(value);
    }
    // Column
    for (int i = 0; i < 9; i++) {
      _candidates[i][c].remove(value);
    }
    // Box
    int startRow = (r ~/ 3) * 3;
    int startCol = (c ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        _candidates[startRow + i][startCol + j].remove(value);
      }
    }
  }

  SolveStep? _findNextMove() {
    // 1. Naked Singles
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_grid[r][c] == 0 && _candidates[r][c].length == 1) {
          return SolveStep(Point(r, c), _candidates[r][c].first, SudokuTechnique.nakedSingle);
        }
      }
    }

    // 2. Hidden Singles
    for (int i = 0; i < 9; i++) {
      // Check row i
      var step = _findHiddenSingleInUnit(List.generate(9, (c) => Point(i, c)));
      if (step != null) return step;
      // Check col i
      step = _findHiddenSingleInUnit(List.generate(9, (r) => Point(r, i)));
      if (step != null) return step;
      // Check box i
      int startRow = (i ~/ 3) * 3;
      int startCol = (i % 3) * 3;
      step = _findHiddenSingleInUnit([
        for (int r = 0; r < 3; r++)
          for (int c = 0; c < 3; c++) Point(startRow + r, startCol + c)
      ]);
      if (step != null) return step;
    }

    return null;
  }

  SolveStep? _findHiddenSingleInUnit(List<Point<int>> unit) {
    for (int n = 1; n <= 9; n++) {
      Point<int>? foundCell;
      int count = 0;
      for (final cell in unit) {
        if (_candidates[cell.x][cell.y].contains(n)) {
          count++;
          foundCell = cell;
        }
      }
      if (count == 1 && _grid[foundCell!.x][foundCell.y] == 0) {
        return SolveStep(foundCell, n, SudokuTechnique.hiddenSingle);
      }
    }
    return null;
  }

  bool _isSolved() {
    return !_grid.any((row) => row.contains(0));
  }

  // --- Brute-force solver for uniqueness check ---

  bool _solveBruteForce(List<List<int>> grid, Function(List<List<int>> solution) onSolved, {int stopAfter = 1}) {
    int solutionCount = 0;

    bool solve() {
      Point<int>? emptyCell = _findEmpty(grid);
      if (emptyCell == null) {
        onSolved(grid);
        solutionCount++;
        return solutionCount >= stopAfter;
      }

      int r = emptyCell.x;
      int c = emptyCell.y;

      for (int num = 1; num <= 9; num++) {
        if (_isSafe(grid, r, c, num)) {
          grid[r][c] = num;
          if (solve()) {
            return true;
          }
          grid[r][c] = 0; // backtrack
        }
      }
      return false;
    }

    solve();
    return solutionCount > 0;
  }

  Point<int>? _findEmpty(List<List<int>> grid) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] == 0) {
          return Point(r, c);
        }
      }
    }
    return null;
  }

  bool _isSafe(List<List<int>> grid, int r, int c, int num) {
    // Check row
    for (int i = 0; i < 9; i++) {
      if (grid[r][i] == num) return false;
    }
    // Check column
    for (int i = 0; i < 9; i++) {
      if (grid[i][c] == num) return false;
    }
    // Check box
    int startRow = (r ~/ 3) * 3;
    int startCol = (c ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (grid[startRow + i][startCol + j] == num) return false;
      }
    }
    return true;
  }
}