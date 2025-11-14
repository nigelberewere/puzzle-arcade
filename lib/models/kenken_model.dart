import 'dart:math';

// FIX: Added 'expert' and 'master' difficulty levels.
enum KenKenDifficulty { easy, medium, hard, expert, master }
enum KenKenOperation { add, subtract, multiply, divide }

class KenKenCage {
  final int target;
  final KenKenOperation operation;
  final List<Point<int>> cells;
  const KenKenCage({required this.target, required this.operation, required this.cells});

  String get targetString {
    switch (operation) {
      case KenKenOperation.add:
        return '$target+';
      case KenKenOperation.subtract:
        return '$target-';
      case KenKenOperation.multiply:
        return '$target×';
      case KenKenOperation.divide:
        return '$target÷';
    }
  }

  Map<String, dynamic> toJson() => {
        'target': target,
        'operation': operation.index,
        'cells': cells.map((p) => {'x': p.x, 'y': p.y}).toList(),
      };

  static KenKenCage fromJson(Map<String, dynamic> json) => KenKenCage(
        target: json['target'] as int,
        operation: KenKenOperation.values[json['operation'] as int],
        cells: (json['cells'] as List)
            .map((p) => Point<int>(p['x'] as int, p['y'] as int))
            .toList(),
      );
}

class KenKenPuzzle {
  final int gridSize;
  final List<KenKenCage> cages;
  final List<List<int>> solution;
  const KenKenPuzzle(
      {required this.gridSize, required this.cages, required this.solution});

  Map<String, dynamic> toJson() => {
        'gridSize': gridSize,
        'cages': cages.map((c) => c.toJson()).toList(),
        'solution': solution,
      };

  static KenKenPuzzle fromJson(Map<String, dynamic> json) => KenKenPuzzle(
        gridSize: json['gridSize'],
        cages: (json['cages'] as List)
            .map((c) => KenKenCage.fromJson(c as Map<String, dynamic>))
            .toList(),
        solution: (json['solution'] as List)
            .map((row) => (row as List).map((e) => e as int).toList())
            .toList(),
      );
}
