import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/achievements_service.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final achievementsService = Provider.of<AchievementsService>(context);
    final achievements = achievementsService.allAchievements;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          final bool isUnlocked = achievement.isUnlocked; // This will be dynamic later

          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            elevation: isUnlocked ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isUnlocked ? theme.colorScheme.primary : theme.dividerColor,
                width: isUnlocked ? 2 : 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              leading: Icon(
                achievement.icon,
                size: 40,
                color: isUnlocked ? theme.colorScheme.primary : theme.disabledColor,
              ),
              title: Text(
                achievement.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? theme.colorScheme.onSurface : theme.disabledColor,
                ),
              ),
              subtitle: Text(
                achievement.description,
                style: TextStyle(color: isUnlocked ? theme.colorScheme.onSurfaceVariant : theme.disabledColor),
              ),
              trailing: isUnlocked
                  ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 32)
                  : Icon(Icons.lock, color: theme.disabledColor, size: 32),
            ),
          );
        },
      ),
    );
  }
}

