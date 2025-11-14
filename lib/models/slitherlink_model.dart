// FIX: Added 'expert' and 'master' difficulty levels.
enum SlitherlinkDifficulty { easy, medium, hard, expert, master }
enum LineState { empty, line, markedEmpty }

class SlitherlinkPuzzle {
  final int rows;
  final int cols;
  final List<List<int?>> clues;
  final List<List<bool>> solutionHorizontalLines;
  final List<List<bool>> solutionVerticalLines;

  const SlitherlinkPuzzle({
    required this.rows,
    required this.cols,
    required this.clues,
    required this.solutionHorizontalLines,
    required this.solutionVerticalLines,
  });

  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'clues': clues,
        'solutionHorizontalLines': solutionHorizontalLines,
        'solutionVerticalLines': solutionVerticalLines,
      };

  factory SlitherlinkPuzzle.fromJson(Map<String, dynamic> json) {
    return SlitherlinkPuzzle(
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      clues: (json['clues'] as List)
          .map((row) => (row as List).map((cell) => cell as int?).toList())
          .toList(),
      solutionHorizontalLines: (json['solutionHorizontalLines'] as List)
          .map((row) => (row as List).map((val) => val as bool).toList())
          .toList(),
      solutionVerticalLines: (json['solutionVerticalLines'] as List)
          .map((row) => (row as List).map((val) => val as bool).toList())
          .toList(),
    );
  }
}
