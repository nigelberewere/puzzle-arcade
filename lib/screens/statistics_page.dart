import 'package:flutter/material.dart';
import '/game_state_manager.dart';
//import 'dart:math';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _selectedIndex = 0;
  late Future<Map<String, GameStats>> _statsFuture;

 final List<String> _gameNames = [
    'Sudoku', 'KenKen', 'Hitori', 'Kakuro', 'Slitherlink', 'Futoshi', 'Nonogram'
  ];

  @override
  void initState() {
    super.initState();
    _statsFuture = GameStateManager.loadGameStats();
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds == 0) return 'N/A';
    final duration = Duration(milliseconds: milliseconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String threeDigitMillis = (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return "$twoDigitMinutes:$twoDigitSeconds.$threeDigitMillis";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, GameStats>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final statsMap = snapshot.data ?? {};
          final gameName = _gameNames[_selectedIndex];
          final gameStats = statsMap[gameName] ?? GameStats();

          if (statsMap.isEmpty && gameStats.puzzlesSolved == 0) {
            return const Center(
              child: Text('No stats yet. Play a game!'),
            );
          }
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(gameName, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _StatCard(
                  icon: Icons.done_all,
                  label: 'Puzzles Solved',
                  value: gameStats.puzzlesSolved.toString(),
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _StatCard(
                  icon: Icons.timer_outlined,
                  label: 'Average Time',
                  value: _formatDuration(gameStats.puzzlesSolved > 0
                      ? gameStats.totalTime ~/ gameStats.puzzlesSolved
                      : 0),
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _StatCard(
                  icon: Icons.emoji_events_outlined,
                  label: 'Best Time',
                  value: _formatDuration(gameStats.bestTime),
                  color: Colors.amber,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_3x3), label: 'Sudoku'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'KenKen'),
          BottomNavigationBarItem(icon: Icon(Icons.hide_source), label: 'Hitori'),
          BottomNavigationBarItem(icon: Icon(Icons.border_all_rounded), label: 'Kakuro'),
          BottomNavigationBarItem(icon: Icon(Icons.change_history), label: 'Slitherlink'),
          BottomNavigationBarItem(icon: Icon(Icons.filter_list_alt), label: 'Futoshi'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: 'Nonogram'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

