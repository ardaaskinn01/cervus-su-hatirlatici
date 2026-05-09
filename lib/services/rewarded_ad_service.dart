import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RewardedAdService {
  static RewardedAd? _ad;
  static bool _isLoaded = false;

  static String get adUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return dotenv.env['REWARDED_AD_IOS'] ??
          'ca-app-pub-2073707860224174/4129249634';
    }
    return dotenv.env['REWARDED_AD_ANDROID'] ??
        'ca-app-pub-2073707860224174/4019392822';
  }

  static Future<void> load() async {
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoaded = true;
          debugPrint('✅ Rewarded Ad yüklendi');
        },
        onAdFailedToLoad: (error) {
          _isLoaded = false;
          debugPrint('❌ Rewarded Ad yüklenemedi: $error');
        },
      ),
    );
  }

  /// Reklamı gösterir. Kullanıcı ödülü kazanırsa `true` döner.
  static Future<bool> show(BuildContext context) async {
    if (!_isLoaded || _ad == null) {
      await load();
      if (!_isLoaded) return false;
    }

    final completer = Completer<bool>();
    bool rewarded = false;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _isLoaded = false;
        load(); // Sonraki kullanım için önceden yükle
        
        // Eğer ödül kazanılmışsa true, yoksa false dönerek tamamla
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        _isLoaded = false;
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await _ad!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        debugPrint('🎁 Kullanıcı ödülü kazandı: ${reward.amount} ${reward.type}');
      },
    );

    return completer.future;
  }
}
