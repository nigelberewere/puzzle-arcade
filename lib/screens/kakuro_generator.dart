import 'dart:math';
import '../models/kakuro_model.dart';

/// Generates new, solvable Kakuro puzzles.
class KakuroGenerator {
  final int rows;
  final int cols;
  late List<List<KakuroCell>> _layout;
  late List<List<int>> _solution;

  KakuroGenerator({this.rows = 8, this.cols = 8});

  /// The main method to generate a new puzzle layout.
  KakuroPuzzle generate() {
    bool success = false;
    int attempts = 0;
    while (!success && attempts < 100) {
      // 1. Create a symmetrical pattern of black and white cells.
      _createPattern();

      // 2. Try to fill the pattern with a valid number solution.
      _solution = List.generate(rows, (_) => List.generate(cols, (_) => 0));
      success = _solve();
      attempts++;
    }

    if (!success) {
      // Fallback if solver fails, generate a simpler pattern
      return KakuroGenerator(rows: rows, cols: cols).generate();
    }

    // 3. Calculate the clues based on the generated solution.
    _calculateClues();

    return KakuroPuzzle(
      rows: rows,
      cols: cols,
      layout: _layout,
      solution: _solution,
    );
  }

  /// Creates a random, symmetrical pattern of playable and non-playable cells.
  void _createPattern() {
    _layout = List.generate(rows, (_) => List.generate(cols, (_) => EntryCell()));

    // Make border cells non-playable
    for (int i = 0; i < rows; i++) {
      _layout[i][0] = EmptyCell();
      _layout[i][cols - 1] = EmptyCell();
    }
    for (int j = 0; j < cols; j++) {
      _layout[0][j] = EmptyCell();
      _layout[rows - 1][j] = EmptyCell();
    }

    // Randomly place symmetrical empty cells
    final random = Random();
    int cellsToPlace = (rows * cols) ~/ 4;
    for (int i = 0; i < cellsToPlace; i++) {
      int r = random.nextInt(rows);
      int c = random.nextInt(cols);

      if (_layout[r][c] is EntryCell) {
        _layout[r][c] = EmptyCell();
        _layout[rows - 1 - r][cols - 1 - c] = EmptyCell(); // Symmetrical placement
      }
    }

    // Ensure no runs are of length 1
    _fixShortRuns();
  }

  /// Prevents runs of length 1, as they are trivial.
  void _fixShortRuns() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_layout[r][c] is! EntryCell) {
          // Check for row run of 1
          if (c + 2 < cols && _layout[r][c+1] is EntryCell && _layout[r][c+2] is! EntryCell) {
            _layout[r][c+1] = EmptyCell();
          }
          // Check for col run of 1
          if (r + 2 < rows && _layout[r+1][c] is EntryCell && _layout[r+2][c] is! EntryCell) {
            _layout[r+1][c] = EmptyCell();
          }
        }
      }
    }
  }

  /// Uses a backtracking algorithm to find a valid solution for the pattern.
  bool _solve() {
    Point<int>? findEmpty = _findUnassignedLocation();
    if (findEmpty == null) {
      return true; // Puzzle is solved
    }

    int row = findEmpty.x;
    int col = findEmpty.y;

    for (int num in List.generate(9, (i) => i + 1)..shuffle()) {
      if (_isSafe(row, col, num)) {
        _solution[row][col] = num;
        if (_solve()) {
          return true;
        }
        _solution[row][col] = 0; // Backtrack
      }
    }
    return false;
  }

  /// Finds the next empty (zero) cell to be filled.
  Point<int>? _findUnassignedLocation() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_layout[r][c] is EntryCell && _solution[r][c] == 0) {
          return Point(r, c);
        }
      }
    }
    return null;
  }

  /// Checks if placing a number in a cell violates Kakuro's duplicate number rule.
  bool _isSafe(int row, int col, int num) {
    // Check for duplicates in the current row run
    int c = col - 1;
    while (c >= 0 && _layout[row][c] is EntryCell) {
      if (_solution[row][c] == num) { return false; }
      c--;
    }
    c = col + 1;
    while (c < cols && _layout[row][c] is EntryCell) {
      if (_solution[row][c] == num) { return false; }
      c++;
    }

    // Check for duplicates in the current column run
    int r = row - 1;
    while (r >= 0 && _layout[r][col] is EntryCell) {
      if (_solution[r][col] == num) { return false; }
      r--;
    }
    r = row + 1;
    while (r < rows && _layout[r][col] is EntryCell) {
      if (_solution[r][col] == num) { return false; }
      r++;
    }

    return true;
  }

  /// Calculates the sum clues for all runs based on the solved grid.
  void _calculateClues() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_layout[r][c] is! EntryCell) {
          int? rowClue = _calculateRunSum(r, c + 1, isRow: true);
          int? colClue = _calculateRunSum(r + 1, c, isRow: false);

          if (rowClue != null || colClue != null) {
            _layout[r][c] = ClueCell(rowClue: rowClue, colClue: colClue);
          } else {
            _layout[r][c] = EmptyCell();
          }
        }
      }
    }
  }

  /// Calculates the sum of a single run starting from a given cell.
  int? _calculateRunSum(int startRow, int startCol, {required bool isRow}) {
    if (isRow) {
      if (startCol >= cols || _layout[startRow][startCol] is! EntryCell) { return null; }
    } else {
      if (startRow >= rows || _layout[startRow][startCol] is! EntryCell) { return null; }
    }

    int sum = 0;
    int r = startRow;
    int c = startCol;

    while(true){
      if (isRow) {
        if (c >= cols || _layout[r][c] is! EntryCell) break;
      } else {
        if (r >= rows || _layout[r][c] is! EntryCell) break;
      }
      sum += _solution[r][c];
      if (isRow) { c++; } else { r++; }
    }
    return sum > 0 ? sum : null;
  }
}
