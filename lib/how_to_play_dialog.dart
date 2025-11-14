import 'package:flutter/material.dart';

class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.help_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          // --- FIX: Wrap the Text widget in an Expanded widget ---
          // This allows the text to wrap to the next line if it's too long,
          // preventing the overflow error.
          const Expanded(
            child: Text('Welcome to Puzzle Arcade!'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Here's a quick guide to get you started:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _Rule(icon: Icons.touch_app, text: 'Select a puzzle from the main screen.'),
            SizedBox(height: 12),
            _Rule(icon: Icons.dashboard, text: 'Choose your preferred difficulty.'),
            SizedBox(height: 12),
            _Rule(icon: Icons.check_circle_outline, text: 'Fill the grid according to the puzzle\'s rules.'),
            SizedBox(height: 12),
            _Rule(icon: Icons.lightbulb_outline, text: 'Use hints if you get stuck, but be wise, they are limited!'),
             SizedBox(height: 12),
            _Rule(icon: Icons.favorite_border, text: 'You have 3 lives. Making a mistake costs a life.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Let\'s Go!'),
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Rule({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
