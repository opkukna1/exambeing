import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;
  
  // 🆕 Counter Logic
  static int _clickCount = 0; 
  static const int _adFrequency = 3; // Har 3rd click par ad dikhega

  // Test Ad Unit ID
  static final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-1310160958851625/4164818744' 
      : 'ca-app-pub-39402560992544/4411460';

  // 1. Load Ad
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

  // 2. Show Ad with Logic
  static void showInterstitialAd(VoidCallback onAdClosed) {
    // Counter badhao
    _clickCount++;

    // Check karo: Kya ye 3rd click hai? (1, 2 skip... 3rd par show)
    // Aur kya Ad loaded hai?
    if (_clickCount % _adFrequency == 0 && _isAdLoaded && _interstitialAd != null) {
      
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isAdLoaded = false;
          loadInterstitialAd(); // Agla ad load karo
          onAdClosed(); // User ko aage bhejo
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isAdLoaded = false;
          loadInterstitialAd();
          onAdClosed();
        },
      );
      
      _interstitialAd!.show();
      
    } else {
      // Agar bari nahi hai ya ad load nahi hua, to seedha aage bhejo
      // User ko lagega app bahut fast hai
      print("Ad Skipped (Counter: $_clickCount)");
      
      // Agar Ad load nahi tha, to background me try karo load karne ka
      if (!_isAdLoaded) {
        loadInterstitialAd();
      }
      
      onAdClosed();
    }
  }
}
