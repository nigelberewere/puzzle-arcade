/// Shared model for Kakuro cells used by the page and generator.
abstract class KakuroCell {}

// FIX: Added 'expert' and 'master' difficulty levels.
enum KakuroSize { small, medium, large, expert, master }

/// A non-playable black/empty cell (no clues).
class EmptyCell extends KakuroCell {}

/// A clue cell that may contain a column (down) clue and/or a row (across) clue.
class ClueCell extends KakuroCell {
  final int? colClue;
  final int? rowClue;
  ClueCell({this.colClue, this.rowClue});
}

/// A playable entry cell where the user places digits.
class EntryCell extends KakuroCell {}


// Moved from GameStateManager to break circular dependency
Map<String, dynamic> kakuroCellToJson(KakuroCell cell) {
  if (cell is EmptyCell) return {'type': 'empty'};
  if (cell is ClueCell) return {'type': 'clue', 'colClue': cell.colClue, 'rowClue': cell.rowClue};
  if (cell is EntryCell) return {'type': 'entry'};
  throw Exception('Unknown KakuroCell type for JSON serialization');
}

KakuroCell kakuroCellFromJson(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'clue':
      return ClueCell(
        colClue: json['colClue'],
        rowClue: json['rowClue'],
      );
    case 'entry':
      return EntryCell();
    case 'empty':
    default:
      return EmptyCell();
  }
}

class KakuroPuzzle {
  final int rows;
  final int cols;
  final List<List<KakuroCell>> layout;
  final List<List<int>> solution;

  const KakuroPuzzle({
    required this.rows,
    required this.cols,
    required this.layout,
    required this.solution,
  });

  Map<String, dynamic> toJson() => {
    'rows': rows,
    'cols': cols,
    'layout': layout
        .map((row) =>
        row.map((cell) => kakuroCellToJson(cell)).toList())
        .toList(),
    'solution': solution,
  };

  factory KakuroPuzzle.fromJson(Map<String, dynamic> json) {
    return KakuroPuzzle(
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      layout: (json['layout'] as List)
          .map((row) => (row as List)
          .map((cellJson) =>
          kakuroCellFromJson(cellJson as Map<String, dynamic>))
          .toList())
          .toList(),
      solution: (json['solution'] as List)
          .map((row) => (row as List).cast<int>())
          .toList(),
    );
  }
}
