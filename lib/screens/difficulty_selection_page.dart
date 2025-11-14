import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '/main.dart'; // To get the Game class
import 'dart:math';

class DifficultySelectionPage extends StatefulWidget {
  final Game game;
  const DifficultySelectionPage({super.key, required this.game});

  @override
  State<DifficultySelectionPage> createState() => _DifficultySelectionPageState();
}

class _DifficultySelectionPageState extends State<DifficultySelectionPage> with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late AnimationController _backgroundAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  Color _getColorForDifficulty(dynamic difficulty) {
    // A more scalable color mapping based on index.
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Theme.of(context).colorScheme.tertiary,
    ];
    int index = 0;
    if (difficulty is Enum) {
      index = difficulty.index;
    } else if (difficulty is int) {
      index = difficulty;
    }
    return colors[min(index, colors.length - 1)];
  }

  String _getTitleForDifficulty(dynamic difficulty) {
    if (difficulty is Enum) {
      // Capitalize the first letter of the enum name.
      return difficulty.name[0].toUpperCase() + difficulty.name.substring(1);
    }
    return difficulty.toString();
  }
  
  IconData _getIconForDifficulty(dynamic difficulty) {
    int index = 0;
     if (difficulty is Enum) {
      index = difficulty.index;
    } else if (difficulty is int) {
      index = difficulty;
    }
    // Assign icons based on difficulty level.
    switch(index) {
      case 0: return Icons.sentiment_very_satisfied;
      case 1: return Icons.sentiment_satisfied;
      case 2: return Icons.sentiment_neutral;
      case 3: return Icons.sentiment_dissatisfied;
      case 4: return Icons.sentiment_very_dissatisfied;
      default: return Icons.whatshot;
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Difficulty'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _backgroundAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha:0.3),
                      theme.colorScheme.secondary.withValues(alpha:0.3),
                    ],
                    stops: [0.0, _backgroundAnimationController.value],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // Smooth Hero animation for the game icon.
                Hero(
                  tag: 'game_icon_${widget.game.name}',
                  child: Icon(widget.game.icon, size: 60, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.game.name,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.game.difficulties.length,
                    itemBuilder: (context, index) {
                      final difficulty = widget.game.difficulties[index];
                      // UI/UX Improvement: Staggered slide and fade animation for each tile.
                      final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _listAnimationController,
                          curve: Interval(
                            0.1 * index,
                            min(0.1 * index + 0.7, 1.0),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      );
                      return AnimatedBuilder(
                        animation: _listAnimationController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(100 * (1 - animation.value), 0),
                            child: Opacity(
                              opacity: animation.value,
                              child: child,
                            ),
                          );
                        },
                        child: DifficultyTile(
                          title: _getTitleForDifficulty(difficulty),
                          color: _getColorForDifficulty(difficulty),
                          icon: _getIconForDifficulty(difficulty),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChangeNotifierProvider(
                                  create: (_) => GameProvider(),
                                  child: widget.game.screenBuilder(difficulty),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom styled tile for selecting a difficulty level.
class DifficultyTile extends StatefulWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const DifficultyTile({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<DifficultyTile> createState() => _DifficultyTileState();
}

class _DifficultyTileState extends State<DifficultyTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // UI/UX Improvement: Refined styling for the difficulty tile.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse().then((_) => widget.onTap()),
          onTapCancel: () => _controller.reverse(),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.color, width: 2),
               boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha:0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.color, size: 36),
                const SizedBox(width: 16),
                Text(
                  widget.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: theme.colorScheme.onSurface.withValues(alpha:0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
