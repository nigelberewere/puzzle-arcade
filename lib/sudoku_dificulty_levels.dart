import 'dart:math';

enum SudokuDifficulty { easy, medium, hard, expert, master, grandmaster, daily }

class SudokuPuzzle {
  final List<List<int>> puzzle;
  final List<List<int>> solution;

  const SudokuPuzzle({required this.puzzle, required this.solution});
}

class SudokuGenerator {
  static SudokuPuzzle generate({required SudokuDifficulty difficulty, int? seed}) {
    const size = 9;
    List<List<int>> solution = List.generate(size, (_) => List.filled(size, 0));
    final random = Random(seed);

    _fillGrid(solution, random);

    List<List<int>> puzzle = List.generate(size, (r) => List<int>.from(solution[r]));

    int numbersToRemove;
    switch (difficulty) {
      case SudokuDifficulty.easy:
        numbersToRemove = 35;
        break;
      case SudokuDifficulty.medium:
        numbersToRemove = 45;
        break;
      case SudokuDifficulty.hard:
        numbersToRemove = 52;
        break;
      case SudokuDifficulty.expert:
        numbersToRemove = 58;
        break;
      case SudokuDifficulty.master:
        numbersToRemove = 64;
        break;
      case SudokuDifficulty.grandmaster:
        numbersToRemove = 70;
        break;
      case SudokuDifficulty.daily:
        numbersToRemove = 55; // Daily has a fixed hard-ish difficulty
        break;
    }

    int removed = 0;
    int attempts = 0;
    while (removed < numbersToRemove && attempts < 1000) {
      int r = random.nextInt(size);
      int c = random.nextInt(size);
      if (puzzle[r][c] != 0) {
        puzzle[r][c] = 0;
        removed++;
      }
      attempts++;
    }

    return SudokuPuzzle(puzzle: puzzle, solution: solution);
  }

  static bool _fillGrid(List<List<int>> grid, Random random) {
    const size = 9;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == 0) {
          final numbers = List.generate(size, (i) => i + 1)..shuffle(random);
          for (int num in numbers) {
            if (_isSafe(grid, r, c, num)) {
              grid[r][c] = num;
              if (_fillGrid(grid, random)) return true;
              grid[r][c] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  static bool _isSafe(List<List<int>> grid, int r, int c, int num) {
    const size = 9;
    for (int i = 0; i < size; i++) {
      if (grid[r][i] == num) return false;
    }
    for (int i = 0; i < size; i++) {
      if (grid[i][c] == num) return false;
    }
    final startRow = r - r % 3;
    final startCol = c - c % 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (grid[i + startRow][j + startCol] == num) return false;
      }
    }
    return true;
  }
}

