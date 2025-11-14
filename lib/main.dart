import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

import 'theme_manager.dart';
import 'settings_manager.dart';
import 'providers/game_provider.dart';
import 'screens/difficulty_selection_page.dart';
import 'settings.dart';
import 'screens/statistics_page.dart';
import 'screens/intro_screen.dart';
import 'services/firebase_service.dart';
import 'services/sound_service.dart';
import 'services/achievements_service.dart';
import 'screens/leaderboard_dialog.dart';
import 'screens/achievements_page.dart';

import 'screens/sudoku_page.dart';
import 'screens/kenken_page.dart';
import 'screens/hitori_page.dart';
import 'screens/kakuro_page.dart';
import 'screens/slitherlink_page.dart';
import 'screens/futoshi_page.dart';
import 'screens/nonogram_page.dart';
import '../managers/tutorial_manager.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // --- Improved Error Handling ---
    // Catch and log Flutter framework errors.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // In a real app, you might send this to a crash reporting service.
      debugPrint("Flutter Error: ${details.exceptionAsString()}");
      if (details.stack != null) {
        debugPrint("Stack Trace:\n${details.stack}");
      }
    };

    // --- Custom Error Widget ---
    // Show a more user-friendly error message in release mode.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      bool isDebug = false;
      assert(() {
        isDebug = true;
        return true;
      }());
      if (isDebug) {
        return ErrorWidget(details.exception);
      }
      return Material(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Oops! Something went wrong.\nPlease try restarting the app.',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    };

    if (!kIsWeb) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        MobileAds.instance.initialize();
      } catch (e) {
        debugPrint("Firebase/Ads initialization failed: $e");
      }
    }

    try {
      await SoundService.instance.loadSounds();
    } catch (e) {
      debugPrint("Sound loading failed: $e");
    }

    final firebaseService = FirebaseService.instance;

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeManager()),
          ChangeNotifierProvider(create: (_) => SettingsManager()),
          ChangeNotifierProvider(create: (_) => AchievementsService(firebaseService)),
          // Added TutorialManager to the providers
          ChangeNotifierProvider(create: (_) => TutorialManager()),
        ],
        child: const PuzzleApp(),
      ),
    );
  }, (error, stack) {
    // Catch and log asynchronous errors.
    debugPrint("Caught Async Error: $error");
    debugPrint("Stack Trace:\n$stack");
  });
}

class Game {
  final String name;
  final IconData icon;
  final List<dynamic> difficulties;
  final Widget Function(dynamic) screenBuilder;
  final Widget Function(int) dailyScreenBuilder;

  Game({
    required this.name,
    required this.icon,
    required this.difficulties,
    required this.screenBuilder,
    required this.dailyScreenBuilder,
  });
}

class PuzzleApp extends StatelessWidget {
  const PuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);

    return MaterialApp(
      title: 'Puzzle Arcade',
      theme: themeManager.lightTheme,
      darkTheme: themeManager.darkTheme,
      themeMode: themeManager.themeMode,
      home: const IntroScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _cardsController;

  final List<Game> games = [
    Game(
      name: 'Sudoku',
      icon: Icons.grid_3x3,
      difficulties:
          SudokuDifficulty.values.where((d) => d != SudokuDifficulty.daily).toList(),
      screenBuilder: (difficulty) =>
          SudokuScreen(difficulty: difficulty as SudokuDifficulty),
      dailyScreenBuilder: (seed) =>
          SudokuScreen(difficulty: SudokuDifficulty.daily, dailyChallengeSeed: seed),
    ),
    Game(
      name: 'KenKen',
      icon: Icons.calculate,
      difficulties: KenKenDifficulty.values,
      screenBuilder: (d) => KenKenScreen(difficulty: d as KenKenDifficulty),
      dailyScreenBuilder: (seed) =>
          KenKenScreen(difficulty: KenKenDifficulty.hard, dailyChallengeSeed: seed),
    ),
    Game(
      name: 'Hitori',
      icon: Icons.hide_source,
      difficulties: HitoriDifficulty.values,
      screenBuilder: (d) => HitoriScreen(difficulty: d as HitoriDifficulty),
      dailyScreenBuilder: (seed) =>
          HitoriScreen(difficulty: HitoriDifficulty.hard, dailyChallengeSeed: seed),
    ),
    Game(
      name: 'Kakuro',
      icon: Icons.border_all_rounded,
      difficulties: KakuroSize.values,
      screenBuilder: (d) => KakuroScreen(difficulty: d as KakuroSize),
      dailyScreenBuilder: (seed) =>
          KakuroScreen(difficulty: KakuroSize.medium, dailyChallengeSeed: seed),
    ),
    Game(
      name: 'Slitherlink',
      icon: Icons.change_history,
      difficulties: SlitherlinkDifficulty.values,
      screenBuilder: (d) =>
          SlitherlinkScreen(difficulty: d as SlitherlinkDifficulty),
      dailyScreenBuilder: (seed) => SlitherlinkScreen(
          difficulty: SlitherlinkDifficulty.medium, dailyChallengeSeed: seed),
    ),
    Game(
      name: 'Futoshi',
      icon: Icons.filter_list_alt,
      difficulties: FutoshiDifficulty.values,
      screenBuilder: (d) => FutoshiScreen(difficulty: d as FutoshiDifficulty),
      dailyScreenBuilder: (seed) =>
          FutoshiScreen(difficulty: FutoshiDifficulty.medium, dailyChallengeSeed: seed),
    ),
    Game(
      name: 'Nonogram',
      icon: Icons.grid_on,
      difficulties: NonogramDifficulty.values,
      screenBuilder: (d) =>
          NonogramScreen(difficulty: d as NonogramDifficulty),
      dailyScreenBuilder: (seed) =>
          NonogramScreen(difficulty: NonogramDifficulty.medium, dailyChallengeSeed: seed),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat(reverse: true);
    _cardsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _cardsController.forward();
    FirebaseService.instance.signInAnonymously();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final dailyGame = games[dayOfYear % games.length];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Arcade'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
              icon: const Icon(Icons.emoji_events_outlined),
              tooltip: 'Achievements',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AchievementsPage()))),
          IconButton(
              icon: const Icon(Icons.leaderboard_outlined),
              tooltip: 'Statistics',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const StatisticsPage()))),
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()))),
        ],
      ),
      // UI/UX Improvement: Using AnimatedBuilder for a dynamic gradient background.
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.brightness == Brightness.dark
                    ? [
                        Colors.black,
                        theme.colorScheme.primary.withValues(alpha:0.5)
                      ]
                    : [
                        theme.colorScheme.primary.withValues(alpha:0.6),
                        theme.colorScheme.secondary.withValues(alpha:0.6)
                      ],
                // The animation controller drives the gradient's movement.
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, _bgController.value],
              ),
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              DailyChallengeCard(game: dailyGame),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final animation =
                        Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _cardsController,
                        curve: Interval(
                          0.1 * index,
                          min(0.1 * index + 0.8, 1.0),
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    );
                    return AnimatedBuilder(
                      animation: _cardsController,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, 50 * (1 - animation.value)),
                        child: Opacity(opacity: animation.value, child: child),
                      ),
                      child: GameCard(game: games[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyChallengeCard extends StatefulWidget {
  final Game game;
  const DailyChallengeCard({super.key, required this.game});

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  late Future<Map<String, dynamic>> _dailyChallengeFuture;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadDailyChallenge();
  }

  void _loadDailyChallenge() {
    _dailyChallengeFuture =
        FirebaseService.instance.getDailyChallenge(widget.game.name);
  }

  void _updateStreak() async {
    final streak = await FirebaseService.instance.getUserStreak();
    if (mounted) {
      setState(() {
        _streak = streak;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _updateStreak();
    // UI/UX Improvement: Added a subtle shadow and refined card styling.
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: theme.colorScheme.surface.withValues(alpha:0.85),
      shadowColor: theme.colorScheme.primary.withValues(alpha:0.2),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dailyChallengeFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
                height: 90, child: Center(child: CircularProgressIndicator()));
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
                              )),
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
                            Text(
                              'Daily ${widget.game.name}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_streak > 1) ...[
                              const SizedBox(width: 8),
                              // UI/UX Improvement: Added a glowing effect for the streak.
                              ShaderMask(
                                shaderCallback: (bounds) => RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.5,
                                  colors: [Colors.orange, Colors.orange.withValues(alpha:0.1)],
                                ).createShader(bounds),
                                child: Icon(Icons.local_fire_department,
                                    color: Colors.white, size: 20),
                              ),
                              Text('$_streak',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCompleted ? 'Completed!' : 'A new puzzle awaits',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha:0.8)),
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
                            builder: (_) =>
                                LeaderboardDialog(gameName: widget.game.name)),
                      ),
                      Icon(
                        isCompleted ? Icons.check_circle : widget.game.icon,
                        color:
                            isCompleted ? Colors.green : theme.colorScheme.primary,
                        size: 36,
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
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
            builder: (context) => DifficultySelectionPage(game: widget.game)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // UI/UX Improvement: Enhanced styling for the game cards.
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse().then((_) => _navigateToGame()),
        onTapCancel: () => _controller.reverse(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surface.withValues(alpha:0.7),
                colorScheme.surfaceContainerHighest.withValues(alpha:0.7)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: colorScheme.primary.withValues(alpha:0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha:0.1),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ]
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                  tag: 'game_icon_${widget.game.name}',
                  child:
                      Icon(widget.game.icon, size: 48, color: colorScheme.primary)),
              const SizedBox(height: 12),
              Text(
                widget.game.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
