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
  String? _error; // Hata mesajını tutacak değişken

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

    final ad = BannerAd(
      adUnitId: _adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdMob Banner yüklendi.');
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _error = null;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob Banner hatası: $error');
          if (mounted) {
            setState(() {
              _isLoaded = false;
              // Hatayı ekranda görebilmek için kaydediyoruz
              _error = 'Ad Error: ${error.code} - ${error.message}';
            });
          }
          ad.dispose();
        },
      ),
    );

    return ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reklam yüklendiyse göster
    if (_isLoaded && _bannerAd != null) {
      return Container(
        color: Colors.white,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // Reklam yüklenemediyse ve hata varsa, Release'de bile ekranda mesajı göster
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.red.withOpacity(0.1),
        width: double.infinity,
        height: 50,
        alignment: Alignment.center,
        child: Text(
          _error!,
          style: const TextStyle(
              color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
