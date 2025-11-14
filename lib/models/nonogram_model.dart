// FIX: Added 'expert' and 'master' difficulty levels.
enum NonogramDifficulty { easy, medium, hard, expert, master }

class NonogramPuzzle {
  final int rows;
  final int cols;
  final List<List<int>> rowClues;
  final List<List<int>> colClues;
  final List<List<bool>> solution;

  const NonogramPuzzle({
    required this.rows,
    required this.cols,
    required this.rowClues,
    required this.colClues,
    required this.solution,
  });
}
