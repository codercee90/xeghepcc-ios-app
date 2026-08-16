import UIKit
import Network
import Capacitor
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?
    
    // Các biến theo dõi mạng
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var isFirstLoad = true

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Ép màu nền của Native Window trùng với màu Splash (#F2F2F7)
        self.window?.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        
        // 1. Khởi tạo Firebase
        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: filePath) {
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }

        // 2. Thiết lập Notification Delegate & Messaging Delegate
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // 3. Đăng ký nhận Remote Notification với Apple APNs
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - APNs & Firebase Token Handling (BẮT BUỘC CHO PUSH NOTIFICATION)

    // Khi APNs đăng ký thành công và trả về Device Token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Gán APNs Token cho Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        // Bắn sự kiện sang Capacitor Bridge để JS/TS nhận token
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    // Khi APNs đăng ký thất bại
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }

    // Khi nhận được Notification ở Background / Foreground
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NotificationCenter.default.post(name: .capacitorDidReceiveRemoteNotification, object: userInfo)
        completionHandler(.newData)
    }

    // MARK: - Firebase Messaging Delegate

    // Nhận FCM Registration Token từ Firebase
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let tokenDict = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: tokenDict)
    }

    // MARK: - UNUserNotificationCenter Delegate (Hiển thị Notification khi App đang mở)

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        NotificationCenter.default.post(name: .capacitorDidReceiveRemoteNotification, object: userInfo)
        
        // Cho phép hiển thị Banner, Sound, Badge ngay cả khi app đang mở ở Foreground
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
