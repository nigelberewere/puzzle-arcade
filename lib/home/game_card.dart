import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_model.dart';
import '../config/game_config.dart';
import '../screens/difficulty_selection_page.dart';

/// A card widget representing an individual game
class GameCard extends StatefulWidget {
  final Game game;
  const GameCard({super.key, required this.game});

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: GameConfig.scaleAnimationMilliseconds),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToGame() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DifficultySelectionPage(game: widget.game),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: '${widget.game.name} puzzle game',
      hint: 'Tap to select difficulty',
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse().then((_) => _navigateToGame()),
          onTapCancel: () => _controller.reverse(),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surface.withValues(alpha: 0.7),
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'game_icon_${widget.game.name}',
                  child: Icon(
                    widget.game.icon,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.game.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
