import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// A service to manage loading and showing rewarded video ads.
class AdService {
  AdService._();
  static final instance = AdService._();

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  // Use test ad unit IDs for development.
  // Replace these with your actual ad unit IDs from AdMob before publishing.
  String get rewardedAdUnitId {
    if (kIsWeb) return '';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ca-app-pub-3940256099942544/5224354917';
      case TargetPlatform.iOS:
        return 'ca-app-pub-3940256099942544/1712485313';
      default:
        return '';
    }
  }

  /// Initializes the Google Mobile Ads SDK.
  void initialize() {
    if (kIsWeb) return; // No mobile ads on web
    try {
      MobileAds.instance.initialize();
    } catch (_) {}
  }

  /// Loads a new rewarded ad.
  void loadRewardedAd() {
    if (kIsWeb) return;
    final adUnitId = rewardedAdUnitId;
    if (adUnitId.isEmpty) return;

    try {
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isAdLoaded = true;
            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _isAdLoaded = false;
                loadRewardedAd(); // Pre-load the next ad
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _isAdLoaded = false;
                loadRewardedAd();
              },
            );
          },
          onAdFailedToLoad: (error) {
            _isAdLoaded = false;
          },
        ),
      );
    } catch (_) {
      _isAdLoaded = false;
    }
  }

  /// Shows the loaded rewarded ad.
  /// The [onRewardEarned] callback is triggered when the user successfully watches the ad.
  void showRewardedAd({required VoidCallback onRewardEarned}) {
    if (kIsWeb) return;
    if (_isAdLoaded && _rewardedAd != null) {
      try {
        _rewardedAd!.show(
          onUserEarnedReward: (ad, reward) {
            onRewardEarned();
          },
        );
      } catch (_) {
        // If showing ad fails, try to load another one for next time
        _isAdLoaded = false;
        _rewardedAd = null;
        loadRewardedAd();
      }
    } else {
      // If the ad isn't loaded, try to load another one for next time.
      loadRewardedAd();
    }
  }
}
