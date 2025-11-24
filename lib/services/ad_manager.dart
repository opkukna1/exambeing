import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;

  // 1. Test Ad Unit ID (Android) - Testing ke liye yehi use karein
  static final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712' 
      : 'ca-app-pub-3940256099942544/4411468910';

  // 2. Ad Load Karne Ka Function (App start hote hi call kar dena)
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          print('Interstitial Ad Failed to Load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  // 3. Ad Dikhane Ka Function
  // 'onAdClosed' wo function hai jo Ad band hone ke baad chalega (Jese navigate karna)
  static void showInterstitialAd(VoidCallback onAdClosed) {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isAdLoaded = false;
          loadInterstitialAd(); // Agli baar ke liye naya ad load karo
          onAdClosed(); // ✅ Ad band hone par User ko aage bhejo
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isAdLoaded = false;
          loadInterstitialAd();
          onAdClosed(); // ✅ Error aaye to bhi user ko aage bhejo
        },
      );
      _interstitialAd!.show();
    } else {
      // Agar Ad load nahi hua, to user ko wait mat karao, seedha aage bhejo
      print("Ad not ready, moving forward...");
      onAdClosed();
      loadInterstitialAd(); // Try loading again
    }
  }
}
