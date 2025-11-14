import 'package:flutter/material.dart';

enum AchievementId {
  sudokuSolved1,
  sudokuSolved10,
  sudokuHard,
  kenkenSolved1,
  kenkenSolved10,
  kenkenHard,
  hitoriSolved1,
  kakuroSolved1,
  slitherlinkSolved1,
  futoshiSolved1,
  nonogramSolved1,
  nonogramMistakeFree,
}

class Achievement {
  final AchievementId id;
  final String game;
  final String title;
  final String description;
  final IconData icon;
  bool isUnlocked;

  Achievement({
    required this.id,
    required this.game,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
  });
}

