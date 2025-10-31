import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

class AdServiceProvider with ChangeNotifier {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isAdShowing = false;

  // Google ki Test Ad Unit ID
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  AdServiceProvider() {
    _loadInterstitialAd(); // Provider bante hi ad load karna shuru kar do
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _loadInterstitialAd() {
    // Agar ad pehle se loaded hai ya dikh raha hai, to naya load mat karo
    if (_isAdLoaded || _isAdShowing) return;

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('Ad loaded and ready.');
          _interstitialAd = ad;
          _isAdLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isAdLoaded = false;
          _interstitialAd?.dispose();
        },
      ),
    );
  }

  // Yeh function ad dikhayega
  void showAdAndNavigate(VoidCallback onAdDismissed) {
    // Check karo ki ad ready hai ya nahi
    if (_interstitialAd != null && _isAdLoaded && !_isAdShowing) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          _isAdShowing = true; // Ad dikh raha hai
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('Ad failed to show: $error');
          ad.dispose();
          _isAdLoaded = false;
          _isAdShowing = false;
          onAdDismissed(); // Ad fail hua, seedha navigate karo
          _loadInterstitialAd(); // Agla ad load karo
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          debugPrint('Ad dismissed.');
          ad.dispose();
          _isAdLoaded = false;
          _isAdShowing = false;
          onAdDismissed(); // Ad band hua, ab navigate karo
          _loadInterstitialAd(); // Agla ad load karo
        },
      );

      _interstitialAd!.show(); // Ad dikhao
    } else {
      // Agar ad ready nahi hai, to seedha navigate karo
      debugPrint('Ad not ready. Navigating directly.');
      onAdDismissed();
      // Ad load karne ki koshish karo (agar pehle se loaded nahi hai)
      if (!_isAdLoaded) {
        _loadInterstitialAd();
      }
    }
  }
}
