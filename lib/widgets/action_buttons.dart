import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onRestart;
  final VoidCallback onHint;
  final int hintCount;

  const ActionButtons({
    super.key,
    required this.onRestart,
    required this.onHint,
    required this.hintCount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
            onPressed: onHint,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text('Hint ($hintCount)')),
        FilledButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh),
            label: const Text('Restart')),
      ],
    );
  }
}
