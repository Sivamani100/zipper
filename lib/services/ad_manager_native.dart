// Native (Android / iOS) implementation of AdManager using google_mobile_ads.

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManagerImpl {
  // ─────────────────────────────────────────────────────────────────────────
  // Ad Unit IDs
  // Test IDs are safe for development. Replace _prod* values before release.
  // Get your real IDs from: https://admob.google.com
  // ─────────────────────────────────────────────────────────────────────────
  static const _testBannerId =
      'ca-app-pub-3940256099942544/6300978111'; // Google test banner
  static const _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917'; // Google test rewarded

  // AdMob Unit IDs from Sivamanikanta's AdMob Console:
  static const _prodBannerId =
      'ca-app-pub-8672489755531567/7793579700';
  static const _prodRewardedId =
      'ca-app-pub-8672489755531567/4920004353';

  // Force test ad units unconditionally (even in release/APK builds)
  static String get _bannerId => _testBannerId;
  static String get _rewardedId => _testRewardedId;

  // ─────────────────────────────────────────────────────────────────────────
  // Rewarded Ad State
  // ─────────────────────────────────────────────────────────────────────────
  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdLoaded = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    loadRewardedAd(); // Pre-load first rewarded ad immediately
  }

  // ─────────────────────────────────────────────────────────────────────────
  /// Returns an adaptive banner ad Widget that takes up the full width of the screen.
  static Widget buildBannerAd() => const _BannerAdWidget();

  // ─────────────────────────────────────────────────────────────────────────
  // Rewarded Ad
  // ─────────────────────────────────────────────────────────────────────────
  static bool get isRewardedAdReady => _isRewardedAdLoaded;

  static void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          debugPrint('[AdManager] Rewarded ad loaded and ready.');
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoaded = false;
          debugPrint('[AdManager] Rewarded ad failed to load: ${error.message}');
        },
      ),
    );
  }

  static void showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onAdDismissed,
  }) {
    if (!_isRewardedAdLoaded || _rewardedAd == null) {
      // Ad not ready — skip and continue
      debugPrint('[AdManager] Rewarded ad not ready, skipping.');
      onAdDismissed?.call();
      loadRewardedAd(); // Try loading for next time
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
        loadRewardedAd(); // Pre-load next ad
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdManager] Rewarded show failed: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
        loadRewardedAd();
        onAdDismissed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('[AdManager] User earned reward: ${reward.amount} ${reward.type}');
        onRewarded();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal Adaptive Banner Widget — loads, shows, and disposes itself automatically
// ─────────────────────────────────────────────────────────────────────────────
class _BannerAdWidget extends StatefulWidget {
  const _BannerAdWidget();

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isAdLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null && !_isAdLoading) {
      _loadAdaptiveAd();
    }
  }

  Future<void> _loadAdaptiveAd() async {
    _isAdLoading = true;
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // Request a custom banner ad size with exactly 80px height and full screen width
    final AdSize customAdSize = AdSize(
      width: screenWidth.truncate(),
      height: 80,
    );

    if (!mounted) return;

    final ad = BannerAd(
      adUnitId: AdManagerImpl._bannerId,
      size: customAdSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdManager] Banner failed: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoading = false;
            });
          }
        },
      ),
    );

    _bannerAd = ad;
    try {
      await ad.load();
    } catch (e) {
      ad.dispose();
      _isAdLoading = false;
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      height: _bannerAd!.size.height.toDouble(),
      width: _bannerAd!.size.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
