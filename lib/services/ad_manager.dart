// Conditional import router — same pattern as audio_manager.dart in this project.
// On web (dart.library.html) → uses stub (no-ops).
// On native Android/iOS (dart.library.io) → uses real google_mobile_ads implementation.

import 'ad_manager_stub.dart'
    if (dart.library.html) 'ad_manager_stub.dart'
    if (dart.library.io) 'ad_manager_native.dart';

import 'package:flutter/material.dart';

/// Central ad manager. Use this class everywhere in the app.
/// On web/unsupported platforms, all calls are no-ops.
abstract class AdManager {
  /// Call once at app start (in main.dart) to initialize the AdMob SDK.
  static Future<void> initialize() => AdManagerImpl.initialize();

  /// Returns a ready-to-use banner ad Widget.
  /// Manages its own lifecycle (load → display → dispose).
  /// Returns SizedBox.shrink() on web or when ad is unavailable.
  static Widget buildBannerAd() => AdManagerImpl.buildBannerAd();

  /// True if a rewarded ad is loaded and ready to show.
  static bool get isRewardedAdReady => AdManagerImpl.isRewardedAdReady;

  /// Pre-load the next rewarded ad (called automatically after each show).
  static void loadRewardedAd() => AdManagerImpl.loadRewardedAd();

  /// Show the rewarded ad full-screen.
  /// [onRewarded]    — called when the user watches the full ad and earns the reward.
  /// [onAdDismissed] — called when the ad closes (whether rewarded or not).
  static void showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onAdDismissed,
  }) =>
      AdManagerImpl.showRewardedAd(
        onRewarded: onRewarded,
        onAdDismissed: onAdDismissed,
      );
}
