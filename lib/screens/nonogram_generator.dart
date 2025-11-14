import 'dart:math';
import '../models/nonogram_model.dart';

class NonogramGenerator {
  final int size;
  late final NonogramSolver _solver;

  NonogramGenerator({required this.size}) {
    _solver = NonogramSolver();
  }

  NonogramPuzzle generate() {
    List<List<bool>> solution;
    NonogramPuzzle puzzle;

    // Keep generating patterns until we find one that is logically solvable
    // without any need for guessing.
    while (true) {
      solution = _createPattern();
      final rowClues = _generateClues(solution, isRowClues: true);
      final colClues = _generateClues(solution, isRowClues: false);
      puzzle = NonogramPuzzle(
        rows: size,
        cols: size,
        rowClues: rowClues,
        colClues: colClues,
        solution: solution,
      );

      // The solver checks if the puzzle can be completed with logic alone.
      if (_solver.isLogicallySolvable(puzzle)) {
        break;
      }
    }

    return puzzle;
  }

  List<List<bool>> _createPattern() {
    final rand = Random();
    var grid = List.generate(size, (_) => List.filled(size, false));

    // Generate a base pattern with a few random shapes
    final int shapes = rand.nextInt(3) + 2;
    for (int i = 0; i < shapes; i++) {
      int r = rand.nextInt(size);
      int c = rand.nextInt(size);
      int width = rand.nextInt(size ~/ 2) + 1;
      int height = rand.nextInt(size ~/ 2) + 1;

      for (int y = r; y < r + height && y < size; y++) {
        for (int x = c; x < c + width && x < size; x++) {
          grid[y][x] = !grid[y][x]; // XOR allows for more interesting shapes
        }
      }
    }

    // Optionally add horizontal symmetry to create more structured images
    if (rand.nextDouble() > 0.5) {
      for (int r = 0; r < size; r++) {
        for (int c = 0; c < size / 2; c++) {
          grid[r][size - 1 - c] = grid[r][c];
        }
      }
    }
    return grid;
  }

  List<List<int>> _generateClues(List<List<bool>> grid, {required bool isRowClues}) {
    final int outerLoop = isRowClues ? size : size;
    final int innerLoop = isRowClues ? size : size;
    final clues = <List<int>>[];

    for (int i = 0; i < outerLoop; i++) {
      final lineClues = <int>[];
      int currentRun = 0;
      for (int j = 0; j < innerLoop; j++) {
        final isFilled = isRowClues ? grid[i][j] : grid[j][i];
        if (isFilled) {
          currentRun++;
        } else {
          if (currentRun > 0) {
            lineClues.add(currentRun);
          }
          currentRun = 0;
        }
      }
      if (currentRun > 0) {
        lineClues.add(currentRun);
      }
      clues.add(lineClues.isEmpty ? [] : lineClues);
    }
    return clues;
  }
}

/// Represents the state of a cell during the solving process.
enum _SolveCellState { unknown, filled, empty }

/// A logical solver for Nonogram puzzles. It does not guess or backtrack.
/// It only fills in cells that can be 100% determined through logic.
class NonogramSolver {
  /// Checks if a puzzle is solvable using only logical deductions.
  ///
  /// Returns `true` if the puzzle can be fully solved without guessing.
  bool isLogicallySolvable(NonogramPuzzle puzzle) {
    var grid = List.generate(
      puzzle.rows,
          (_) => List.filled(puzzle.cols, _SolveCellState.unknown),
    );

    // Continuously apply solving logic to rows and columns until no more
    // cells can be deduced. We do two passes with no changes to ensure
    // that all possible interactions between rows and columns are resolved.
    int passesWithNoChanges = 0;
    while (passesWithNoChanges < 2) {
      int changesMade = 0;

      // Process all rows
      for (int r = 0; r < puzzle.rows; r++) {
        final (updatedLine, lineChanges) = _solveLine(
          List.generate(puzzle.cols, (c) => grid[r][c]),
          puzzle.rowClues[r],
        );
        if (lineChanges > 0) {
          changesMade += lineChanges;
          for (int c = 0; c < puzzle.cols; c++) {
            grid[r][c] = updatedLine[c];
          }
        }
      }

      // Process all columns
      for (int c = 0; c < puzzle.cols; c++) {
        final (updatedLine, lineChanges) = _solveLine(
          List.generate(puzzle.rows, (r) => grid[r][c]),
          puzzle.colClues[c],
        );
        if (lineChanges > 0) {
          changesMade += lineChanges;
          for (int r = 0; r < puzzle.rows; r++) {
            grid[r][c] = updatedLine[r];
          }
        }
      }

      if (changesMade == 0) {
        passesWithNoChanges++;
      } else {
        passesWithNoChanges = 0;
      }
    }

    // If any cell is still unknown, the puzzle requires guessing and is therefore
    // not considered "logically solvable" for our generator's purposes.
    return !grid.any((row) => row.any((cell) => cell == _SolveCellState.unknown));
  }

  /// Solves a single line (a row or column) based on its current state and clues.
  ///
  /// This function generates all possible valid arrangements for the line that
  /// don't conflict with already-solved cells. It then finds the "intersection"
  /// of these possibilities. If a cell is filled in ALL possibilities, it must
  /// be filled. If it's empty in ALL possibilities, it must be empty.
  (List<_SolveCellState>, int) _solveLine(List<_SolveCellState> line, List<int> clues) {
    final List<List<bool>> possibilities = [];
    _generatePossibilities(line.length, clues, [], possibilities);

    // Filter out possibilities that contradict the current line state
    possibilities.removeWhere((p) {
      for (int i = 0; i < line.length; i++) {
        if (line[i] == _SolveCellState.filled && !p[i]) return true;
        if (line[i] == _SolveCellState.empty && p[i]) return true;
      }
      return false;
    });

    if (possibilities.isEmpty) return (line, 0);

    var updatedLine = List<_SolveCellState>.from(line);
    int changes = 0;

    for (int i = 0; i < line.length; i++) {
      if (line[i] == _SolveCellState.unknown) {
        bool allFilled = possibilities.every((p) => p[i]);
        bool allEmpty = possibilities.every((p) => !p[i]);

        if (allFilled) {
          updatedLine[i] = _SolveCellState.filled;
          changes++;
        } else if (allEmpty) {
          updatedLine[i] = _SolveCellState.empty;
          changes++;
        }
      }
    }
    return (updatedLine, changes);
  }

  /// Recursively generates all possible valid arrangements for a given set of clues.
  void _generatePossibilities(int lineSize, List<int> clues, List<bool> current, List<List<bool>> result) {
    if (clues.isEmpty) {
      // Base case: No more clues to place. Fill the rest with empty cells.
      if (current.length < lineSize) {
        current.addAll(List.filled(lineSize - current.length, false));
      }
      result.add(current);
      return;
    }

    int clue = clues.first;
    List<int> remainingClues = clues.sublist(1);
    int remainingLength = remainingClues.fold(0, (sum, c) => sum + c) + remainingClues.length;

    for (int i = 0; i <= lineSize - current.length - remainingLength - clue; i++) {
      List<bool> next = List.from(current);
      // Add empty cells before the current block
      next.addAll(List.filled(i, false));
      // Add the block of filled cells
      next.addAll(List.filled(clue, true));
      // Add the mandatory empty cell separator (if it's not the last clue)
      if (remainingClues.isNotEmpty) {
        next.add(false);
      }
      _generatePossibilities(lineSize, remainingClues, next, result);
    }
  }
}

