import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '/widgets/game_info_bar.dart';

class GameScaffold extends StatelessWidget {
  final String title;
  final Widget gameBoard;
  final Widget numberPad;
  final List<Widget> actionButtons;

  const GameScaffold({
    super.key,
    required this.title,
    required this.gameBoard,
    required this.numberPad,
    required this.actionButtons,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Consumer<GameProvider>(
                builder: (context, game, child) => GameInfoBar(
                  lives: game.lives,
                  elapsedTime: game.elapsedTime,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(child: gameBoard),
              ),
              const SizedBox(height: 24),
              numberPad,
              const SizedBox(height: 20),
              Wrap(
                spacing: 12.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: actionButtons,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
