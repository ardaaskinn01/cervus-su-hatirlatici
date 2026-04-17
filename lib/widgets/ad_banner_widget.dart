import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // —— Reklam Birimi ID'leri ——————————————————————————————
  // BU ID'LERİ GERÇEK AD UNIT ID'LERİNİZLE DEĞİŞTİRİN.
  // Format: ca-app-pub-XXXXXXXX/YYYYYYY  (~ DEĞİL, / ile ayrılır)
  static const String _androidAdUnitId =
      'ca-app-pub-2073707860224174/5672841140';
  static const String _iosAdUnitId =
      'ca-app-pub-2073707860224174/8299004484';

  String get _adUnitId => Platform.isIOS ? _iosAdUnitId : _androidAdUnitId;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob Banner failed to load: $error');
          ad.dispose();
        },
      ),
    );
    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
