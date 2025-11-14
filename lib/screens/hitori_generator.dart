import 'dart:math';
import 'dart:collection';
import '../models/hitori_model.dart';

/// A generator for creating valid and solvable Hitori puzzles.
class HitoriGenerator {
  final int gridSize;
  late List<List<int>> _solution;
  late List<List<bool>> _isShaded;
  late List<List<int>> _puzzle;

  HitoriGenerator({required this.gridSize});

  /// Generates a new Hitori puzzle.
  HitoriPuzzle generate() {
    _generateSolution();
    _selectShadedCells();
    _createPuzzleFromSolution();

    return HitoriPuzzle(
      gridSize: gridSize,
      puzzle: _puzzle,
      isShaded: _isShaded,
    );
  }

  /// 1. Create a valid "Latin Square" which will serve as the solved state.
  ///    (No repeated numbers in any row or column).
  void _generateSolution() {
    _solution = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    final random = Random();

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final possibleNumbers = List<int>.generate(gridSize, (i) => i + 1)..shuffle(random);
        bool placed = false;
        for (final number in possibleNumbers) {
          if (_isSafe(r, c, number)) {
            _solution[r][c] = number;
            placed = true;
            break;
          }
        }
        if (!placed) {
          // This can happen with a naive approach, if so, just restart.
          // A more robust solver (like backtracking) would be better but is more complex.
          // For game generation, this simple approach is often sufficient.
          _generateSolution();
          return;
        }
      }
    }
  }

  bool _isSafe(int r, int c, int num) {
    for (int i = 0; i < gridSize; i++) {
      if (_solution[r][i] == num || _solution[i][c] == num) {
        return false;
      }
    }
    return true;
  }

  /// 2. Randomly select cells to be shaded, ensuring Hitori rules are not violated.
  void _selectShadedCells() {
    _isShaded = List.generate(gridSize, (_) => List.filled(gridSize, false));
    final random = Random();
    int cellsToShade = (gridSize * gridSize * 0.25).toInt(); // Shade ~25% of cells

    for (int i = 0; i < cellsToShade; i++) {
      int r = random.nextInt(gridSize);
      int c = random.nextInt(gridSize);

      if (_canBeShaded(r, c)) {
        _isShaded[r][c] = true;
      }
    }
  }

  bool _canBeShaded(int r, int c) {
    // Rule 2: Shaded cells cannot be adjacent
    for (final neighbor in _getNeighbors(r, c)) {
      if (_isShaded[neighbor.x][neighbor.y]) {
        return false;
      }
    }

    // Rule 3: Must not isolate unshaded cells
    _isShaded[r][c] = true; // Temporarily shade it to check connectivity
    bool isConnected = _checkConnectivity();
    _isShaded[r][c] = false; // Backtrack

    return isConnected;
  }

  /// 3. Create the final puzzle by replacing numbers in un-shaded cells
  ///    to create the duplicates that the player must find.
  void _createPuzzleFromSolution() {
    _puzzle = List<List<int>>.generate(gridSize, (r) => List<int>.from(_solution[r]));
    final random = Random();

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_isShaded[r][c]) {
          // This number needs to appear elsewhere in its row or column
          bool placedDuplicate = false;
          int attempts = 0;
          while(!placedDuplicate && attempts < 50) {
            if(random.nextBool()) { // try row
              int randomCol = random.nextInt(gridSize);
              if(!_isShaded[r][randomCol]) {
                _puzzle[r][randomCol] = _puzzle[r][c];
                placedDuplicate = true;
              }
            } else { // try col
              int randomRow = random.nextInt(gridSize);
              if(!_isShaded[randomRow][c]) {
                _puzzle[randomRow][c] = _puzzle[r][c];
                placedDuplicate = true;
              }
            }
            attempts++;
          }
        }
      }
    }
  }

  /// Checks if all un-shaded cells are connected.
  bool _checkConnectivity() {
    Point<int>? firstUnshaded;
    int unshadedCount = 0;
    final visited = <Point<int>>{};

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!_isShaded[r][c]) {
          unshadedCount++;
          firstUnshaded ??= Point(r, c);
        }
      }
    }

    if (firstUnshaded == null) return true; // All cells shaded

    final queue = Queue<Point<int>>()..add(firstUnshaded);
    visited.add(firstUnshaded);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final neighbor in _getNeighbors(current.x, current.y)) {
        if (!_isShaded[neighbor.x][neighbor.y] && !visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }
    return visited.length == unshadedCount;
  }

  List<Point<int>> _getNeighbors(int r, int c) {
    final neighbors = <Point<int>>[];
    if (r > 0) neighbors.add(Point(r - 1, c));
    if (r < gridSize - 1) neighbors.add(Point(r + 1, c));
    if (c > 0) neighbors.add(Point(r, c - 1));
    if (c < gridSize - 1) neighbors.add(Point(r, c + 1));
    return neighbors;
  }
}
