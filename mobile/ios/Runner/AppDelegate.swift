import Flutter
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Cấu hình Firebase native trước khi gán APNs token (plist phải nằm trong target Resources).
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Cần để nhận push khi app foreground / background (FCM + APNs).
    // Template UIScene của Flutter không tự gọi đủ — phải register tay.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // firebase_messaging không luôn nhận APNs token trên UIScene — gán tay.
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HrmAppBadge") {
      let channel = FlutterMethodChannel(
        name: "com.minhan.hrm/app_badge",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "setBadge" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let count = (call.arguments as? Int) ?? 0
        DispatchQueue.main.async {
          if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
              if let error {
                result(
                  FlutterError(
                    code: "badge",
                    message: error.localizedDescription,
                    details: nil
                  )
                )
              } else {
                result(nil)
              }
            }
          } else {
            UIApplication.shared.applicationIconBadgeNumber = count
            result(nil)
          }
        }
      }
    }
  }
}
