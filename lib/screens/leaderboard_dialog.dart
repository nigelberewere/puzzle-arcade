import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class LeaderboardDialog extends StatefulWidget {
  final String gameName;
  const LeaderboardDialog({super.key, required this.gameName});

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog> {
  late Future<List<LeaderboardScore>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = FirebaseService.instance.getLeaderboard(widget.gameName);
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds == 0) return '--:--';
    final duration = Duration(milliseconds: milliseconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Daily ${widget.gameName} Leaderboard'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<LeaderboardScore>>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No scores yet for today!'));
            }
            final scores = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              itemCount: scores.length,
              itemBuilder: (context, index) {
                final score = scores[index];
                return ListTile(
                  leading: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  title: Text(score.userName),
                  trailing: Text(
                    _formatDuration(score.timeMillis),
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

