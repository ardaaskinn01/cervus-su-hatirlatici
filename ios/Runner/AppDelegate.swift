import Flutter
import UIKit
import FirebaseCore
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 🔥 Ana Firebase projesini iOS native seviyesinde, Flutter plugin'den ÖNCE başlatıyoruz.
    // Bu sayede FLTFirebaseCorePlugin geldiğinde uygulama zaten kayıtlı olur ve çakışma olmaz.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Arka plan işlemleri (Notification Action) için gerekli
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
