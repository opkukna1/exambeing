import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;
  
  // Counter Variable
  static int _clickCount = 0; 

  // ✅ TEST AD UNIT IDs (Development ke liye yehi use karein)
  static final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'  // Google Test ID (Android)
      : 'ca-app-pub-3940256099942544/4411468910'; // Google Test ID (iOS)

  // 1. Ad Load Karne Ka Function
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print("Test Ad Loaded Successfully");
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

  // 2. Show Ad with "2 Show, 2 Skip" Logic
  static void showInterstitialAd(VoidCallback onAdClosed) {
    // Counter badhao
    _clickCount++;

    // Cycle Logic (Total 4 steps ka cycle)
    // 1st Click: Show (Remainder 1)
    // 2nd Click: Show (Remainder 2)
    // 3rd Click: Skip (Remainder 3)
    // 4th Click: Skip (Remainder 0)
    // 5th Click: Show (Wapas 1)
    
    int positionInCycle = _clickCount % 4;
    
    // Ad tabhi dikhao jab cycle 1 ya 2 par ho
    bool shouldShow = (positionInCycle == 1 || positionInCycle == 2);

    print("Ad Click Count: $_clickCount (Cycle Pos: $positionInCycle) -> Show: $shouldShow");

    // Agar bari hai AUR ad load hai -> Tabhi Dikhao
    if (shouldShow && _isAdLoaded && _interstitialAd != null) {
      
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          // Ad band hone par kya karein
          ad.dispose();
          _isAdLoaded = false;
          loadInterstitialAd(); // Agla ad load karo
          onAdClosed(); // User ko aage bhejo
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          // Agar ad fail ho jaye dikhane mein
          print("Ad Failed to Show: $error");
          ad.dispose();
          _isAdLoaded = false;
          loadInterstitialAd();
          onAdClosed();
        },
      );
      
      _interstitialAd!.show();
      
    } else {
      // Agar bari nahi hai (Skip turn) ya ad ready nahi hai
      print("Ad Skipped (Logic or Not Ready)");
      
      // Agar Ad load nahi tha (lekin bari thi), to background me load karne ki koshish karo
      if (!_isAdLoaded) {
        loadInterstitialAd();
      }
      
      onAdClosed(); // User ko turant aage bhejo
    }
  }
}
