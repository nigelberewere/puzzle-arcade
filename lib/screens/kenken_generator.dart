import 'dart:math';
import '../models.dart';

/// A class to generate new KenKen puzzles.
class KenKenGenerator {
  final int gridSize;

  late List<List<int>> _grid; // The solution grid
  late List<KenKenCage> _cages;
  late List<List<bool>> _cellAssigned;

  KenKenGenerator({required this.gridSize}) {
    _grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    _cages = [];
    _cellAssigned = List.generate(gridSize, (_) => List.filled(gridSize, false));
  }

  KenKenPuzzle generate() {
    _generateLatinSquare();
    _generateCages();

    // Create a copy of the solution to include in the puzzle object
    final List<List<int>> solutionCopy = List.generate(gridSize, (r) => List<int>.from(_grid[r]));

    return KenKenPuzzle(
      gridSize: gridSize,
      cages: _cages,
      solution: solutionCopy, // Include the solution for the hint system
    );
  }

  // --- Private Generation Methods ---

  void _generateLatinSquare() {
    _fillCell(0, 0);
  }

  bool _fillCell(int r, int c) {
    if (r == gridSize) {
      return true;
    }
    int nextR = (c == gridSize - 1) ? r + 1 : r;
    int nextC = (c == gridSize - 1) ? 0 : c + 1;

    final numbers = List.generate(gridSize, (i) => i + 1)..shuffle();
    for (int num in numbers) {
      if (_isSafe(r, c, num)) {
        _grid[r][c] = num;
        if (_fillCell(nextR, nextC)) {
          return true;
        }
        _grid[r][c] = 0; // Backtrack
      }
    }
    return false;
  }

  bool _isSafe(int r, int c, int num) {
    for (int i = 0; i < gridSize; i++) {
      if (_grid[r][i] == num || _grid[i][c] == num) {
        return false;
      }
    }
    return true;
  }

  void _generateCages() {
    final rand = Random();
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!_cellAssigned[r][c]) {
          _createCage(r, c, rand);
        }
      }
    }
  }

  void _createCage(int r, int c, Random rand) {
    List<Point<int>> cells = [Point(r, c)];
    _cellAssigned[r][c] = true;

    // Cages can be 1 to 4 cells. Smaller cages are more common.
    int cageSize = 1 + (rand.nextDouble() < 0.6 ? rand.nextInt(2) : rand.nextInt(4));
    cageSize = min(cageSize, 4); // Max cage size of 4

    while (cells.length < cageSize) {
      final lastCell = cells.last;
      List<Point<int>> neighbors = _getUnassignedNeighbors(lastCell);
      if (neighbors.isEmpty) break;

      neighbors.shuffle();
      final nextCell = neighbors.first;
      cells.add(nextCell);
      _cellAssigned[nextCell.x][nextCell.y] = true;
    }

    // Determine operation and target
    _finalizeCage(cells, rand);
  }

  List<Point<int>> _getUnassignedNeighbors(Point<int> cell) {
    List<Point<int>> neighbors = [];
    final directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (var dir in directions) {
      int nR = cell.x + dir[0];
      int nC = cell.y + dir[1];
      if (nR >= 0 && nR < gridSize && nC >= 0 && nC < gridSize && !_cellAssigned[nR][nC]) {
        neighbors.add(Point(nR, nC));
      }
    }
    return neighbors;
  }

  void _finalizeCage(List<Point<int>> cells, Random rand) {
    final values = cells.map((p) => _grid[p.x][p.y]).toList();
    if (values.length == 1) {
      _cages.add(KenKenCage(target: values[0], operation: KenKenOperation.add, cells: cells));
      return;
    }

    final operations = <KenKenOperation>[];
    // Add & Multiply are always possible
    operations.add(KenKenOperation.add);
    operations.add(KenKenOperation.multiply);

    // Subtract & Divide are only possible for 2-cell cages
    if (values.length == 2) {
      if (values[0] != values[1]) {
        operations.add(KenKenOperation.subtract);
      }
      if (values[0] % values[1] == 0 || values[1] % values[0] == 0) {
        operations.add(KenKenOperation.divide);
      }
    }

    operations.shuffle();
    final operation = operations.first;
    int target = 0;

    switch (operation) {
      case KenKenOperation.add:
        target = values.reduce((a, b) => a + b);
        break;
      case KenKenOperation.multiply:
        target = values.reduce((a, b) => a * b);
        break;
      case KenKenOperation.subtract:
        target = (values[0] - values[1]).abs();
        break;
      case KenKenOperation.divide:
        target = (values[0] > values[1] ? values[0] ~/ values[1] : values[1] ~/ values[0]);
        break;
    }

    _cages.add(KenKenCage(target: target, operation: operation, cells: cells));
  }
}

