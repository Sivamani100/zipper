// Stub implementation for web or unsupported platforms.
// All methods are no-ops so the app compiles and runs without ads on web.

import 'package:flutter/material.dart';

class AdManagerImpl {
  static Future<void> initialize() async {}

  static Widget buildBannerAd() => const SizedBox.shrink();

  static bool get isRewardedAdReady => false;

  static void loadRewardedAd() {}

  static void showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onAdDismissed,
  }) {
    // No-op on web — just dismiss immediately
    onAdDismissed?.call();
  }
}
