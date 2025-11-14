import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math'; // FIX: Added import for the Random class.
import '../game_state_manager.dart';
import '../models/achievement.dart';

/// Represents the user's profile data stored in Firebase.
class UserProfile {
  final String uid;
  final String displayName;
  final int streak;
  final DateTime lastCompletionDate;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.streak,
    required this.lastCompletionDate,
  });
}

/// Represents a single score entry on the daily leaderboard.
class LeaderboardScore {
  final String userId;
  final String userName;
  final int timeMillis;

  LeaderboardScore({
    required this.userId,
    required this.userName,
    required this.timeMillis,
  });
}

/// A singleton service to handle all Firebase interactions.
///
/// This includes authentication, fetching daily challenges, managing user profiles,
/// submitting scores, and handling achievements.
class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Provides a stream of the current user's authentication state.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Signs in the user anonymously if they are not already signed in.
  /// Does nothing on the web platform.
  Future<void> signInAnonymously() async {
    if (kIsWeb || _auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
      debugPrint("Signed in anonymously.");
    } on FirebaseAuthException catch (e) {
      debugPrint("Anonymous sign-in failed: ${e.message}");
    }
  }

  /// Initiates the Google Sign-In flow and authenticates with Firebase.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) return;
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        debugPrint("Google Sign-In aborted by user.");
        return; // User cancelled the sign-in
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      debugPrint("Signed in with Google.");
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Google Auth failed: ${e.message}");
    } on PlatformException catch (e) {
      debugPrint("Platform error during Google Sign-In: ${e.message}");
    } catch (e) {
      debugPrint("An unexpected error occurred during Google Sign-In: $e");
    }
  }

  /// Signs out the current user from Firebase and Google.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
      debugPrint("User signed out.");
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  /// Fetches the daily challenge seed for a given game.
  ///
  /// On web, it generates a deterministic seed. On mobile, it tries to fetch
  /// from Firestore, creating it if it doesn't exist, and falls back to a
  /// deterministic seed on failure.
  Future<Map<String, dynamic>> getDailyChallenge(String gameName) async {
    final today = DateTime.now();
    final dateString =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final fallbackSeed = today.year * 10000 + today.month * 100 + today.day;

    if (kIsWeb) {
      final isCompleted = await GameStateManager.isDailyCompleted(fallbackSeed);
      return {'seed': fallbackSeed, 'isCompleted': isCompleted};
    }

    try {
      final docRef = _firestore.collection('daily_challenges').doc(dateString);
      final doc = await docRef.get();
      int seed;
      final seedField = '${gameName.toLowerCase()}_seed';

      if (doc.exists && doc.data()!.containsKey(seedField)) {
        seed = doc.data()![seedField];
      } else {
        seed = fallbackSeed;
        // Set or update the document with the new seed for today's game
        await docRef.set({seedField: seed}, SetOptions(merge: true));
      }

      final isCompleted = await GameStateManager.isDailyCompleted(seed);
      return {'seed': seed, 'isCompleted': isCompleted};
    } catch (e) {
      debugPrint("Failed to get daily challenge from Firestore. Using fallback. Error: $e");
      final isCompleted = await GameStateManager.isDailyCompleted(fallbackSeed);
      return {'seed': fallbackSeed, 'isCompleted': isCompleted};
    }
  }

  /// Retrieves the current user's profile from Firestore.
  Future<UserProfile?> getUserProfile() async {
    if (kIsWeb || _auth.currentUser == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (!doc.exists) {
        // Create a default profile if it doesn't exist
        await updateUserDisplayName('Player${Random().nextInt(1000)}');
        return await getUserProfile();
      }
      final data = doc.data()!;
      return UserProfile(
        uid: _auth.currentUser!.uid,
        displayName: data['displayName'] ?? 'Player',
        streak: data['streak'] ?? 0,
        lastCompletionDate: (data['lastCompletionDate'] as Timestamp? ?? Timestamp.now()).toDate(),
      );
    } catch (e) {
      debugPrint("Error getting user profile: $e");
      return null;
    }
  }

  /// Updates the display name for the current user.
  Future<void> updateUserDisplayName(String newName) async {
    if (kIsWeb || _auth.currentUser == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .set({'displayName': newName}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating display name: $e");
    }
  }

  /// Submits the user's score for a completed daily challenge.
  Future<void> submitDailyChallengeScore(
      {required String gameName, required int timeMillis}) async {
    if (kIsWeb || _auth.currentUser == null) return;

    final user = _auth.currentUser!;
    final today = DateTime.now();
    final dateString =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    try {
      final profile = await getUserProfile();
      final displayName = profile?.displayName ?? 'Player';

      await _firestore
          .collection('daily_challenges')
          .doc(dateString)
          .collection(gameName.toLowerCase())
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'userName': displayName,
        'timeMillis': timeMillis,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _updateStreak();
    } catch (e) {
      debugPrint("Failed to submit daily score: $e");
    }
  }

  /// Updates the user's daily challenge completion streak.
  Future<void> _updateStreak() async {
    if (kIsWeb || _auth.currentUser == null) return;
    final user = _auth.currentUser!;
    final docRef = _firestore.collection('users').doc(user.uid);

    try {
      final doc = await docRef.get();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (doc.exists) {
        final data = doc.data()!;
        final currentStreak = data['streak'] as int? ?? 0;
        final lastCompletionTimestamp = data['lastCompletionDate'] as Timestamp?;

        if (lastCompletionTimestamp != null) {
          final lastDay = lastCompletionTimestamp.toDate();
          final lastDayDateOnly = DateTime(lastDay.year, lastDay.month, lastDay.day);
          
          if (lastDayDateOnly == today) return; // Already completed today
          
          if (lastDayDateOnly == today.subtract(const Duration(days: 1))) {
            await docRef.update({'streak': currentStreak + 1, 'lastCompletionDate': Timestamp.now()});
          } else {
            await docRef.update({'streak': 1, 'lastCompletionDate': Timestamp.now()});
          }
        } else {
           await docRef.update({'streak': 1, 'lastCompletionDate': Timestamp.now()});
        }
      } else {
        await docRef.set({'streak': 1, 'lastCompletionDate': Timestamp.now(), 'displayName': 'Player${Random().nextInt(1000)}'});
      }
    } catch (e) {
      debugPrint("Failed to update streak: $e");
    }
  }

  /// Fetches the current user's streak, returns 0 if streak is broken.
  Future<int> getUserStreak() async {
    if (kIsWeb || _auth.currentUser == null) return 0;
    try {
      final doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (!doc.exists) return 0;

      final data = doc.data()!;
      final streak = data['streak'] as int? ?? 0;
      final lastCompletionTimestamp = data['lastCompletionDate'] as Timestamp?;
      if (lastCompletionTimestamp == null) return 0;

      final lastCompletionDate = lastCompletionTimestamp.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastDay = DateTime(lastCompletionDate.year, lastCompletionDate.month, lastCompletionDate.day);
      
      // If the last completion was today or yesterday, the streak is valid. Otherwise, it's broken.
      if (lastDay == today || lastDay == yesterday) {
        return streak;
      } else {
        return 0; // Streak is broken
      }
    } catch (e) {
      debugPrint("Error getting user streak: $e");
      return 0;
    }
  }

  /// Fetches the top 20 scores for a given game's daily challenge.
  Future<List<LeaderboardScore>> getLeaderboard(String gameName) async {
    if (kIsWeb) return [];
    final today = DateTime.now();
    final dateString =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    try {
      final snapshot = await _firestore
          .collection('daily_challenges')
          .doc(dateString)
          .collection(gameName.toLowerCase())
          .orderBy('timeMillis')
          .limit(20)
          .get();
      return snapshot.docs
          .map((doc) => LeaderboardScore(
                userId: doc.data()['userId'] ?? '',
                userName: doc.data()['userName'] ?? 'Player',
                timeMillis: doc.data()['timeMillis'] ?? 0,
              ))
          .toList();
    } catch (e) {
      debugPrint("Error fetching leaderboard: $e");
      return [];
    }
  }

  /// Unlocks a specific achievement for the current user.
  Future<void> unlockAchievement(AchievementId achievementId) async {
    if (kIsWeb || _auth.currentUser == null) return;
    final userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid);
    try {
      await userDoc.set({
        'achievements': FieldValue.arrayUnion([achievementId.name])
      }, SetOptions(merge: true));
    } catch(e) {
       debugPrint("Error unlocking achievement: $e");
    }
  }

  /// Retrieves the set of unlocked achievement IDs for the current user.
  Future<Set<String>> getUnlockedAchievements() async {
    if (kIsWeb || _auth.currentUser == null) return {};
    try {
      final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('achievements')) {
        final achievements = List<String>.from(userDoc.data()!['achievements']);
        return achievements.toSet();
      }
    } catch (e) {
      debugPrint("Error fetching achievements: $e");
    }
    return {};
  }
}

