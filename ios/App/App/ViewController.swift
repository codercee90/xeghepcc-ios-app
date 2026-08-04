import UIKit
import Capacitor
import Network

class ViewController: CAPBridgeViewController {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var isFirstLoad = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Lắng nghe sự kiện mạng ở tầng Native OS
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                // Khi iOS cấp quyền WLAN và có Internet
                DispatchQueue.main.async {
                    if self?.isFirstLoad == false {
                        // Tải lại WebView khi vừa có mạng
                        self?.webView?.reload()
                    }
                    self?.isFirstLoad = false
                }
            }
        }
        monitor.start(queue: queue)
    }
}
