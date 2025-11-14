import 'package:flutter/material.dart';

class TutorialOverlay extends StatelessWidget {
  final String text;
  final VoidCallback onNext;
  final Alignment alignment;
  final Rect highlightRect;

  const TutorialOverlay({
    super.key,
    required this.text,
    required this.onNext,
    this.alignment = Alignment.center,
    required this.highlightRect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: highlightRect,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onNext,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
