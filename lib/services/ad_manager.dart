import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoading = false;
  static int _clickCount = 0;

  // ✅ TEST AD UNIT IDs
  static final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-1310160958851625/4164818744'
      : 'ca-app-pub-3940256099942544/4410';

  // 1. Load Ad (Smart Load)
  static void loadInterstitialAd() {
    if (_interstitialAd != null || _isAdLoading) return; // Duplicate request roko

    _isAdLoading = true;
    print("🔄 Requesting Ad from AdMob...");

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print("✅ Ad Loaded & Ready");
          _interstitialAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          print('❌ Ad Failed to Load: $error');
          _interstitialAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  // 2. Show Ad (Logic: Even Clicks pe dikhao - 2nd, 4th, 6th...)
  static void showInterstitialAd(VoidCallback onAdClosed) {
    _clickCount++;
    print("🖱️ User Click Count: $_clickCount");

    // LOGIC: Har 'Even' number pe ad dikhao (2, 4, 6...)
    // Click 1: Skip
    // Click 2: SHOW
    // Click 3: Skip
    // Click 4: SHOW
    bool shouldShow = (_clickCount % 2 == 0);

    if (shouldShow && _interstitialAd != null) {
      print("🎬 Showing Ad Now...");
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          print("👋 Ad Closed by User");
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd(); // Agla ad load karo
          onAdClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print("⚠️ Failed to show ad: $error");
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd();
          onAdClosed();
        },
      );
      _interstitialAd!.show();
    } else {
      // Agar bari nahi hai, ya ad load nahi hua
      if (shouldShow && _interstitialAd == null) {
         print("⚠️ Bari thi par Ad Load nahi tha! (Missed Opportunity)");
         loadInterstitialAd(); // Turant load karo agli baar ke liye
      } else {
         print("⏭️ Skipping Ad (User Experience)");
         // Agar ad load nahi hai to background me load pe laga do
         if (_interstitialAd == null) loadInterstitialAd();
      }
      
      onAdClosed();
    }
  }
}
