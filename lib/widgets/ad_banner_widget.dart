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
  static const String _androidAdUnitId =
      'ca-app-pub-2073707860224174/5672841140';
  static const String _iosAdUnitId =
      'ca-app-pub-2073707860224174/8299004484';

  String get _adUnitId => Platform.isIOS ? _iosAdUnitId : _androidAdUnitId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Adaptive boyutu hesaplamak için MediaQuery gerektiği için burada çağırıyoruz
    if (_bannerAd == null) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    // Cihazın genişliğine göre en iyi reklam boyutunu (Adaptive) hesapla
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            MediaQuery.of(context).size.width.truncate());

    if (size == null) return;

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdMob Banner yüklendi.');
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob Banner hatası: $error');
          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
          ad.dispose();
        },
      ),
    );

    return _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sadece reklam yüklendiyse göster, aksi durumda (hata veya yükleme) alanı boş bırak
    if (_isLoaded && _bannerAd != null) {
      return Container(
        color: Colors.white,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return const SizedBox.shrink();
  }
}
