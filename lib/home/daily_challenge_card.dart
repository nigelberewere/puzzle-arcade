import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_model.dart';
import '../services/firebase_service.dart';
import '../providers/game_provider.dart';
import '../screens/leaderboard_dialog.dart';
import '../widgets/loading_skeleton.dart';

/// A card displaying the daily challenge
class DailyChallengeCard extends StatefulWidget {
  final Game game;
  const DailyChallengeCard({super.key, required this.game});

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  late Future<Map<String, dynamic>> _dailyChallengeFuture;
  late Future<int> _streakFuture;

  @override
  void initState() {
    super.initState();
    _loadDailyChallenge();
  }

  void _loadDailyChallenge() {
    _dailyChallengeFuture = FirebaseService.instance.getDailyChallenge(widget.game.name);
    _streakFuture = FirebaseService.instance.getUserStreak();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Daily ${widget.game.name} challenge',
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dailyChallengeFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 90,
                child: CardSkeleton(),
              );
            }

            final data = snapshot.data!;
            final isCompleted = data['isCompleted'] as bool;
            final seed = data['seed'] as int;

            return InkWell(
              onTap: isCompleted
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangeNotifierProvider(
                            create: (_) => GameProvider(),
                            child: widget.game.dailyScreenBuilder(seed),
                          ),
                        ),
                      ).then((_) => setState(_loadDailyChallenge));
                    },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Daily ${widget.game.name}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              FutureBuilder<int>(
                                future: _streakFuture,
                                builder: (context, streakSnapshot) {
                                  final streak = streakSnapshot.data ?? 0;
                                  if (streak <= 1) return const SizedBox.shrink();
                                  
                                  return Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      ShaderMask(
                                        shaderCallback: (bounds) => RadialGradient(
                                          center: Alignment.center,
                                          radius: 0.5,
                                          colors: [
                                            Colors.orange,
                                            Colors.orange.withValues(alpha: 0.1),
                                          ],
                                        ).createShader(bounds),
                                        child: const Icon(
                                          Icons.local_fire_department,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      Text(
                                        '$streak',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCompleted ? 'Completed!' : 'A new puzzle awaits',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.leaderboard),
                          tooltip: 'Leaderboard',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => LeaderboardDialog(gameName: widget.game.name),
                          ),
                        ),
                        Icon(
                          isCompleted ? Icons.check_circle : widget.game.icon,
                          color: isCompleted
                              ? Colors.green
                              : theme.colorScheme.primary,
                          size: 36,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
