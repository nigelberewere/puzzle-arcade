//import 'dart:math';

// FIX: Added 'expert' and 'master' difficulty levels.
enum HitoriDifficulty { easy, medium, hard, expert, master }

/// Represents the state of a single cell in the Hitori grid.
enum HitoriCellState {
  normal, // The default, untouched state.
  shaded, // Marked by the user as a "black" cell.
  circled, // Marked by the user as a "white" cell to keep.
}


class HitoriPuzzle {
  final int gridSize;
  final List<List<int>> puzzle;
  final List<List<bool>> isShaded; // The solution

  const HitoriPuzzle({
    required this.gridSize,
    required this.puzzle,
    required this.isShaded,
  });

  Map<String, dynamic> toJson() => {
    'gridSize': gridSize,
    'puzzle': puzzle,
    'isShaded': isShaded,
  };

  factory HitoriPuzzle.fromJson(Map<String, dynamic> json) {
    return HitoriPuzzle(
      gridSize: json['gridSize'] as int,
      puzzle: (json['puzzle'] as List)
          .map((row) => (row as List).cast<int>())
          .toList(),
      isShaded: (json['isShaded'] as List)
          .map((row) => (row as List).cast<bool>())
          .toList(),
    );
  }
}
