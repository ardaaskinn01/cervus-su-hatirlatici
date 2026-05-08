import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
export 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/user_provider.dart';

class RevenueCatService {
  static bool _isConfigured = false;

  static Future<void> init(BuildContext context) async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);

      String apiKey = "";
      if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUECAT_ANDROID_KEY'] ?? "goog_CdKPYBXhbZiLNyviaUoCHkeooJx";
      } else {
        apiKey = dotenv.env['REVENUECAT_IOS_KEY'] ?? "appl_zMfQsclGkpPBQeXPmcfJbTIpWch";
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _isConfigured = true;

      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      final isPro = customerInfo.entitlements.all["pro"]?.isActive ?? false;
      
      if (context.mounted) {
        context.read<UserProvider>().updatePremiumStatus(isPro);
      }
    } catch (e) {
      debugPrint("RevenueCat Init Error: $e");
    }
  }

  static Future<Offerings?> getOfferings() async {
    if (!_isConfigured) {
      debugPrint("RevenueCat is not configured yet — skipping getOfferings.");
      return null;
    }
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint("Offerings hatası: $e");
      return null;
    }
  }

  static Future<bool> purchasePackage(BuildContext context, Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      final customerInfo = result.customerInfo;
      final isPro = customerInfo.entitlements.all["pro"]?.isActive ?? false;

      if (context.mounted) {
        context.read<UserProvider>().updatePremiumStatus(isPro);
        if (isPro) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Satın alım başarılı!'), backgroundColor: Colors.green),
          );
        }
      }
      return isPro;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Satın alma kullanıcı tarafından iptal edildi.");
        return false;
      }
      debugPrint("Satın alma hatası: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alım başarısız oldu.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Beklenmedik satın alma hatası: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
    return false;
  }

  static Future<bool> restorePurchases(BuildContext context) async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      final isPro = customerInfo.entitlements.all["pro"]?.isActive ?? false;

      if (context.mounted) {
        context.read<UserProvider>().updatePremiumStatus(isPro);
        if (isPro) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Satın alımınız geri yüklendi!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geri yüklenecek abonelik bulunamadı.'), backgroundColor: Colors.orange),
          );
        }
      }
      return isPro;
    } catch (e) {
      debugPrint("Geri yükleme hatası: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geri yükleme başarısız oldu.'), backgroundColor: Colors.red),
        );
      }
    }
    return false;
  }
}
