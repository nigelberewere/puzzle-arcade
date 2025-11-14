/// Configuration constants for the game
class GameConfig {
  // Lives and Hints Configuration
  static const int maxLives = 3;
  static const int maxHints = 3;
  static const int initialLives = 3;
  
  // Leaderboard Configuration
  static const int leaderboardLimit = 20;
  static const int leaderboardPageSize = 10;
  
  // Timer Configuration
  static const int timerUpdateIntervalSeconds = 1;
  
  // Animation Configuration
  static const int confettiDurationSeconds = 1;
  static const int cardAnimationMilliseconds = 1200;
  static const int scaleAnimationMilliseconds = 150;
  static const int backgroundAnimationSeconds = 20;
  
  // Ad Configuration
  static const int rewardedAdHintGrant = 1;
  static const int rewardedAdLifeGrant = 1;
  
  // Offline Configuration
  static const int offlineRetryDelaySeconds = 3;
  static const int networkTimeoutSeconds = 10;
  
  // Cache Configuration
  static const int achievementsCacheDurationMinutes = 5;
  static const int leaderboardCacheDurationMinutes = 2;
  
  // Generator Configuration
  static const int maxGenerationAttempts = 1000;
  
  // Private constructor to prevent instantiation
  GameConfig._();
}
