import 'package:flutter/material.dart';

class WinSummaryDialog extends StatelessWidget {
  final String timeTaken;
  final String difficulty;
  final int points;
  final int hintsUsed;
  final int mistakesMade;
  final VoidCallback? onPlayAgain;
  final VoidCallback onDone;

  const WinSummaryDialog({
    super.key,
    required this.timeTaken,
    required this.difficulty,
    required this.points,
    required this.hintsUsed,
    required this.mistakesMade,
    this.onPlayAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 60),
          const SizedBox(height: 16),
          Text('Puzzle Complete!', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Difficulty: $difficulty',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.secondary),
          ),
          const SizedBox(height: 24),
          _StatRow(icon: Icons.timer_outlined, label: 'Time', value: timeTaken),
          const Divider(),
          _StatRow(icon: Icons.star_outline, label: 'Points Gained', value: '+$points'),
          const Divider(),
          _StatRow(icon: Icons.lightbulb_outline, label: 'Hints Used', value: hintsUsed.toString()),
          const Divider(),
          _StatRow(icon: Icons.favorite_border, label: 'Mistakes', value: mistakesMade.toString()),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: onDone, child: const Text('Done')),
        if (onPlayAgain != null)
          FilledButton(onPressed: onPlayAgain, child: const Text('Play Again')),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodyLarge),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

