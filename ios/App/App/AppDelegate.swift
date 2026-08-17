import UIKit
import Network
import Capacitor
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// Khai báo mở rộng Notification Name chuẩn xác cho Capacitor
extension Notification.Name {
    static let capacitorDidRegisterForRemoteNotifications = Notification.Name("capacitorDidRegisterForRemoteNotifications")
    static let capacitorDidFailToRegisterForRemoteNotifications = Notification.Name("capacitorDidFailToRegisterForRemoteNotifications")
    static let capacitorDidReceiveRemoteNotification = Notification.Name("capacitorDidReceiveRemoteNotification")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var isFirstLoad = true

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window?.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)

        // 1. Kiểm tra an toàn Provisioning Profile (Bọc do-catch chống crash)
        var canUsePush = false
        if let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            do {
                let content = try String(contentsOfFile: path, encoding: .isoLatin1)
                // Kiểm tra xem có phải profile chính chủ và không phải free/dev profile không
                if content.contains("HK58UX9N3D") && !content.contains("iOS Team Provisioning Profile") {
                    canUsePush = true
                }
            } catch {
                print("==> Không đọc được file embedded.mobileprovision: \(error)")
            }
        }

        // 2. Khởi tạo Firebase AN TOÀN (Bọc chống Crash do thiếu GoogleService-Info.plist)
        setupFirebaseSafely()

        // 3. CHỈ ĐĂNG KÝ PUSH KHI ĐỦ QUYỀN & FIREBASE ĐÃ SẴN SÀNG
        if canUsePush && FirebaseApp.app() != nil {
            UNUserNotificationCenter.current().delegate = self
            Messaging.messaging().delegate = self
            application.registerForRemoteNotifications()
            print("==> Đã kích hoạt Push Notification.")
        } else {
            print("==> Chế độ Sideload/3uTools/Ký cá nhân: Đã tắt Push Notification Delegate để tránh văng App.")
        }

        return true
    }

    // MARK: - Hàm khởi tạo Firebase an toàn
    private func setupFirebaseSafely() {
        // Nếu Firebase đã được khởi tạo trước đó thì bỏ qua
        guard FirebaseApp.app() == nil else { return }

        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: filePath) {
            FirebaseApp.configure(options: options)
            print("==> Firebase configured thành công từ GoogleService-Info.plist")
        } else {
            print("⚠️ CẢNH BÁO: KHÔNG tìm thấy file GoogleService-Info.plist. Bỏ qua khởi tạo Firebase để tránh văng App trên 3uTools.")
        }
    }

    // MARK: - APNs Remote Notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NotificationCenter.default.post(name: .capacitorDidReceiveRemoteNotification, object: userInfo)
        completionHandler(.newData)
    }

    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let tokenDict = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: tokenDict)
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        NotificationCenter.default.post(name: .capacitorDidReceiveRemoteNotification, object: userInfo)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(name: .capacitorDidReceiveRemoteNotification, object: userInfo)
        completionHandler()
    }

    // MARK: - App Lifecycle & Deep Links
    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
