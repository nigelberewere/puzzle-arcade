import 'dart:math';

enum SudokuDifficulty { easy, medium, hard, expert, master, daily }

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

    // Fill the grid with a valid solution
    _fillGrid(solution, random);

    // Create a copy for the puzzle
    List<List<int>> puzzle = List.generate(size, (r) => List<int>.from(solution[r]));

    // Remove numbers to create the puzzle
    int numbersToRemove;
    switch (difficulty) {
      case SudokuDifficulty.easy:
        numbersToRemove = 40;
        break;
      case SudokuDifficulty.medium:
        numbersToRemove = 50;
        break;
      case SudokuDifficulty.expert:
        numbersToRemove = 54; // More challenging
        break;
      case SudokuDifficulty.master:
        numbersToRemove = 58; // Nearing the limits
        break;
      case SudokuDifficulty.hard:
      case SudokuDifficulty.daily: // Daily challenge has hard difficulty
        numbersToRemove = 52; // Adjusted hard to make space for new levels
        break;
    }

    int attempts = 0;
    for (int i = 0; i < numbersToRemove && attempts < 1000; i++) {
      int r = random.nextInt(size);
      int c = random.nextInt(size);
      if (puzzle[r][c] != 0) {
        puzzle[r][c] = 0;
      } else {
        i--; // Try again
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
              if (_fillGrid(grid, random)) {
                return true;
              }
              grid[r][c] = 0; // Backtrack
            }
          }
          return false; // No valid number found
        }
      }
    }
    return true; // Grid is full
  }

  static bool _isSafe(List<List<int>> grid, int r, int c, int num) {
    const size = 9;
    // Check row
    for (int i = 0; i < size; i++) {
      if (grid[r][i] == num) return false;
    }
    // Check column
    for (int i = 0; i < size; i++) {
      if (grid[i][c] == num) return false;
    }
    // Check 3x3 box
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
