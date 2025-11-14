import 'package:flutter/material.dart';

class GameInfoBar extends StatelessWidget {
  final int lives;
  final String elapsedTime;

  const GameInfoBar({
    super.key,
    required this.lives,
    required this.elapsedTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // IMPROVEMENT: Added Semantics for screen readers.
        Semantics(
          label: '$lives ${lives == 1 ? "life" : "lives"} remaining',
          child: Row(
            children: List.generate(
                3,
                (index) => Icon(
                      index < lives ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                      // IMPROVEMENT: Exclude individual icons from semantics tree.
                      semanticLabel: '', 
                    )),
          ),
        ),
        Row(
          children: [
            Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            // IMPROVEMENT: Added Semantics for screen readers.
            Semantics(
              label: 'Elapsed time: $elapsedTime',
              child: Text(
                elapsedTime,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    // Ensures numbers don't shift width, providing a stable layout.
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
