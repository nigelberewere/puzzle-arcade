import 'package:flutter/material.dart';

/// Represents a single game in the puzzle arcade
class Game {
  final String name;
  final IconData icon;
  final List<dynamic> difficulties;
  final Widget Function(dynamic) screenBuilder;
  final Widget Function(int) dailyScreenBuilder;

  const Game({
    required this.name,
    required this.icon,
    required this.difficulties,
    required this.screenBuilder,
    required this.dailyScreenBuilder,
  });
}
