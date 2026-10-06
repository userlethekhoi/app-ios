import Foundation
import Combine

/// File/notification bridge used by an optional companion tweak.
///
/// A sandboxed App Store build can read its own Documents folder. Cross-app
/// purchase handoff requires an external companion that can see one of the
/// shared bridge paths below; writing a local Documents file is not enough
/// because the target app has a separate iOS sandbox.
public final class TweakBridge: ObservableObject {
    public static let shared = TweakBridge()

    @Published public private(set) var snapshots: [ScanSnapshot] = []
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var lastBridgeMessage = "Chưa kết nối bridge"
    @Published public private(set) var isBatchScanning = false
    @Published public private(set) var batchScanStatus = ""

    private let fileManager = FileManager.default
    private var pendingLaunchQueue: [String] = []

    public init() {
        loadAllSnapshots()
        // The companion tweak posts this Darwin notification right after it
        // persists a snapshot, so the catalog refreshes without a manual pull.
        let callback: CFNotificationCallback = { _, _, _, _, _ in
            TweakBridge.shared.loadAllSnapshots()
            StoreKitService.shared.loadRealData()
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            callback,
            "com.adr.checkiap.snapshot" as CFString,
            nil,
            .deliverImmediately
        )
    }

    public var searchPaths: [URL] {
        var paths: [URL] = []
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            paths.append(documents.appendingPathComponent("IAPCheck", isDirectory: true))
        }
        paths.append(URL(fileURLWithPath: "/var/mobile/Documents/IAPCheck", isDirectory: true))
        paths.append(URL(fileURLWithPath: "/var/jb/var/mobile/Documents/IAPCheck", isDirectory: true))
        paths.append(URL(fileURLWithPath: "/tmp/IAPCheck", isDirectory: true))
        return paths
    }

    private var externalBridgePaths: [URL] {
        Array(searchPaths.dropFirst())
    }

    public func loadAllSnapshots() {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [ScanSnapshot] = []
            var seen = Set<String>()
            for folder in self.searchPaths {
                guard self.fileManager.fileExists(atPath: folder.path),
                      let files = try? self.fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
                for file in files where file.pathExtension.lowercased() == "json" && !file.lastPathComponent.lowercased().hasPrefix("pending_") {
                    guard let data = try? Data(contentsOf: file),
                          let snapshot = self.decodeSnapshot(data: data, file: file) else { continue }
                    if seen.insert(snapshot.id).inserted { found.append(snapshot) }
                }
            }
            DispatchQueue.main.async {
                self.snapshots = found.sorted { $0.timestamp > $1.timestamp }
                self.lastSyncDate = Date()
                self.lastBridgeMessage = found.isEmpty ? "Chưa có snapshot" : "Đã đồng bộ \(found.count) snapshot"
            }
        }
    }

    public func importJSONString(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        do {
            guard let snapshot = decodeSnapshot(data: data, file: nil) else {
                throw IAPError.failed("JSON không có snapshot hoặc danh sách products hợp lệ.")
            }
            saveSnapshotLocally(snapshot)
            loadAllSnapshots()
            return true
        } catch {
            DispatchQueue.main.async { self.lastBridgeMessage = "JSON không hợp lệ: \(error.localizedDescription)" }
            return false
        }
    }

    public func saveSnapshotLocally(_ snapshot: ScanSnapshot) {
        guard let folder = searchPaths.first else { return }
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: folder.appendingPathComponent("\(snapshot.bundleId)_\(snapshot.timestamp).json"), options: .atomic)
        } catch {
            DispatchQueue.main.async { self.lastBridgeMessage = "Không thể lưu snapshot: \(error.localizedDescription)" }
        }
    }

    /// Writes a command that the companion tweak can consume while its target
    /// app is running. No receipt or transaction is fabricated here.
    @discardableResult
    public func triggerRemotePurchase(
        bundleId: String,
        productId: String,
        mode: PaymentMode = .direct,
        launchTarget: Bool = false,
        adamID: String? = nil
    ) -> Bool {
        var payload: [String: Any] = [
            "bundleId": bundleId,
            "productId": productId,
            "mode": mode.rawValue.lowercased(),
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        if let adamID { payload["adamId"] = adamID }
        var writeSucceeded = false
        // Write to all accessible bridge paths (both shared system paths and app Documents)
        for folder in searchPaths {
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: folder.appendingPathComponent("pending_buy.json"), options: .atomic)
                writeSucceeded = true
            } catch {
                continue
            }
        }

        if writeSucceeded {
            DispatchQueue.main.async { self.lastBridgeMessage = "Đã gửi lệnh \(mode.rawValue) tới \(bundleId)" }
            let notificationName = CFNotificationName("com.adr.checkiap.trigger_buy" as CFString)
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, nil, nil, true)
            if launchTarget { InstalledAppsScanner.shared.launchApp(bundleId: bundleId) }
            return true
        } else {
            DispatchQueue.main.async { self.lastBridgeMessage = "Chưa có companion bridge có thể nhận lệnh cross-app" }
            return false
        }
    }

    // MARK: Scan requests (pending_scan.json)

    /// The latest snapshot captured for one app, or nil when the tweak has
    /// not written one yet.
    public func latestSnapshot(for bundleId: String) -> ScanSnapshot? {
        snapshots.filter { $0.bundleId == bundleId }.max { $0.timestamp < $1.timestamp }
    }

    /// Queue a scan entry addressed to the target app. The tweak inside that
    /// app refetches the listed product ids (merged with ids harvested from
    /// its local receipt) the next time it is running — or immediately via
    /// the Darwin notification if it is already running.
    @discardableResult
    public func requestCatalogScan(bundleId: String, productIds: [String] = [], autoLaunch: Bool = true) -> Bool {
        let entry: [String: Any] = ["bundleId": bundleId, "productIds": productIds]
        guard writePendingScan(entries: [entry]) else {
            DispatchQueue.main.async { self.lastBridgeMessage = "Chưa ghi được lệnh quét vào bridge" }
            return false
        }
        postScanNotification()
        DispatchQueue.main.async { self.lastBridgeMessage = "Đã xếp lệnh quét cho \(bundleId)" }
        if autoLaunch { InstalledAppsScanner.shared.launchApp(bundleId: bundleId) }
        return true
    }

    /// Queue a scan entry addressed to this app with a `proxyFor` bundle.
    /// While the entry is pending the tweak inside storekitd spoofs the
    /// client's bundle id, so this app's own SKProductsRequest resolves the
    /// target's catalogue — no need to launch the target app at all.
    @discardableResult
    public func requestProxyScan(bundleId: String, productIds: [String]) -> Bool {
        guard !productIds.isEmpty,
              let ownBundle = Bundle.main.bundleIdentifier else { return false }
        let entry: [String: Any] = ["bundleId": ownBundle, "proxyFor": bundleId, "productIds": productIds]
        guard writePendingScan(entries: [entry]) else {
            DispatchQueue.main.async { self.lastBridgeMessage = "Chưa ghi được lệnh proxy scan vào bridge" }
            return false
        }
        postScanNotification()
        DispatchQueue.main.async { self.lastBridgeMessage = "Đang quét catalog \(bundleId) qua bridge" }
        return true
    }

    /// Scan every supplied app in one pass:
    ///  - apps whose product ids are already known are queued as proxy scans
    ///    which this app resolves immediately through the daemon spoof;
    ///  - every app also gets a direct entry consumed by the tweak inside it
    ///    on next launch;
    ///  - `launchSequentially` additionally opens each app with a short delay
    ///    so its entry is consumed right away.
    public func requestWholeDeviceScan(apps: [InstalledAppInfo], launchSequentially: Bool) {
        let ownBundle = Bundle.main.bundleIdentifier ?? ""
        var entries: [[String: Any]] = []
        var launchQueue: [String] = []
        for app in apps {
            let ids = StoreKitService.shared.catalogProductIds(for: app.bundleId)
            if !ids.isEmpty, !ownBundle.isEmpty, app.bundleId != ownBundle {
                entries.append(["bundleId": ownBundle, "proxyFor": app.bundleId, "productIds": ids])
            }
            entries.append(["bundleId": app.bundleId, "productIds": ids])
            if ids.isEmpty { launchQueue.append(app.bundleId) }
        }
        guard !entries.isEmpty else { return }
        guard writePendingScan(entries: entries) else {
            DispatchQueue.main.async { self.lastBridgeMessage = "Chưa ghi được hàng đợi quét vào bridge" }
            return
        }
        postScanNotification()
        DispatchQueue.main.async {
            self.isBatchScanning = true
            self.batchScanStatus = "Đã gửi \(entries.count) lệnh quét"
        }
        if launchSequentially {
            launchQueueSerially(launchQueue)
        } else {
            DispatchQueue.main.async { self.isBatchScanning = false }
        }
    }

    // MARK: Pending scan file plumbing

    private func writePendingScan(entries: [[String: Any]]) -> Bool {
        var merged = pendingScanEntries()
        for entry in entries {
            let bundle = entry["bundleId"] as? String
            let proxy = entry["proxyFor"] as? String
            if let index = merged.firstIndex(where: {
                ($0["bundleId"] as? String) == bundle && ($0["proxyFor"] as? String) == proxy
            }) {
                merged[index] = entry
            } else {
                merged.append(entry)
            }
        }
        let payload: [String: Any] = [
            "mode": "scan",
            "timestamp": Int(Date().timeIntervalSince1970),
            "requests": merged
        ]
        var succeeded = false
        for folder in searchPaths {
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: folder.appendingPathComponent("pending_scan.json"), options: .atomic)
                succeeded = true
            } catch {
                continue
            }
        }
        return succeeded
    }

    private func pendingScanEntries() -> [[String: Any]] {
        for folder in searchPaths {
            let url = folder.appendingPathComponent("pending_scan.json")
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let dictionary = object as? [String: Any] else { continue }
            if let requests = dictionary["requests"] as? [[String: Any]] { return requests }
            if dictionary["bundleId"] != nil { return [dictionary] }
        }
        return []
    }

    private func postScanNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.adr.checkiap.scan" as CFString),
            nil, nil, true
        )
    }

    private func launchQueueSerially(_ bundles: [String]) {
        pendingLaunchQueue = bundles
        launchNextQueuedApp()
    }

    private func launchNextQueuedApp() {
        guard !pendingLaunchQueue.isEmpty else {
            DispatchQueue.main.async {
                self.isBatchScanning = false
                self.batchScanStatus = "Đã mở xong hàng đợi app"
            }
            return
        }
        let bundle = pendingLaunchQueue.removeFirst()
        DispatchQueue.main.async {
            self.batchScanStatus = "Đang mở \(bundle) — còn \(self.pendingLaunchQueue.count)"
        }
        InstalledAppsScanner.shared.launchApp(bundleId: bundle)
        // Give each app a few seconds: the tweak hooks its launch, consumes
        // the queued entry and captures whatever catalog it can resolve.
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            self.launchNextQueuedApp()
        }
    }

    public func deleteSnapshot(_ snapshot: ScanSnapshot) {
        snapshots.removeAll { $0.id == snapshot.id }
        for folder in searchPaths {
            guard let files = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.lastPathComponent.contains(snapshot.bundleId) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    public func clearCache() {
        for folder in searchPaths {
            guard fileManager.fileExists(atPath: folder.path) else { continue }
            try? fileManager.removeItem(at: folder)
        }
        snapshots = []
        lastBridgeMessage = "Đã xóa cache bridge"
    }

    // The tweak writes a compact `<bundle>_iap.json` export containing
    // `timestamp`, `totalProducts`, and `products`. Older bridge versions
    // wrote the ScanSnapshot shape directly. Accept both shapes so a valid
    // tweak export is not silently discarded just because its wrapper differs.
    private func decodeSnapshot(data: Data, file: URL?) -> ScanSnapshot? {
        if let snapshot = try? JSONDecoder().decode(ScanSnapshot.self, from: data) {
            return snapshot
        }

        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let rawProducts = dictionary["products"] as? [[String: Any]],
              !rawProducts.isEmpty else { return nil }

        let bundleID = bridgeString(dictionary, keys: ["bundleId", "bundleID", "bundleIdentifier"])
            ?? file.flatMap { bundleIDFromFilename($0) }
            ?? "unknown.app"
        let timestamp = bridgeDouble(dictionary["timestamp"])
            ?? (file.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate?.timeIntervalSince1970 })
            ?? Date().timeIntervalSince1970
        let products = rawProducts.compactMap(decodeProduct)
        guard !products.isEmpty else { return nil }
        return ScanSnapshot(bundleId: bundleID, timestamp: timestamp, products: products)
    }

    private func decodeProduct(_ dictionary: [String: Any]) -> ProductModel? {
        guard let productID = bridgeString(dictionary, keys: ["productId", "productID", "productIdentifier", "identifier", "id"]),
              !productID.isEmpty else { return nil }
        let rawType = bridgeString(dictionary, keys: ["productType", "type", "kind"])?.uppercased() ?? "INAPP"
        let productType: ProductType = rawType.contains("SUBS") ? .subs : .inapp
        let title = bridgeString(dictionary, keys: ["title", "displayName", "localizedTitle", "name"]) ?? productID
        let description = bridgeString(dictionary, keys: ["description", "localizedDescription"]) ?? ""
        let price = bridgeString(dictionary, keys: ["formattedBasePrice", "formattedPrice", "displayPrice", "priceString"]) ?? "N/A"
        let offers = dictionary["offers"] as? [[String: Any]] ?? []
        let offerText = offers.compactMap { bridgeString($0, keys: ["classification", "offerType", "summaryText", "type"]) }.joined(separator: " ").uppercased()
        let hasTrial = bridgeBool(dictionary, keys: ["hasFreeTrial", "hasTrial", "freeTrial", "isTrial"])
            ?? offerText.contains("TRIAL")
            || offerText.contains("FREE")
        let hasDiscount = bridgeBool(dictionary, keys: ["hasIntroDiscount", "hasDiscount", "isDiscounted", "introDiscount"])
            ?? offerText.contains("INTRO")
            || offerText.contains("DISCOUNT")
            || offerText.contains("PROMO")
        return ProductModel(
            productId: productID,
            productType: productType,
            title: title,
            description: description,
            formattedBasePrice: price,
            hasFreeTrial: hasTrial,
            hasIntroDiscount: hasDiscount
        )
    }

    private func bundleIDFromFilename(_ file: URL) -> String? {
        var name = file.deletingPathExtension().lastPathComponent
        if name.hasSuffix("_iap") { name = String(name.dropLast(4)) }
        // `<bundleId>_<epoch>.json` exports written by saveSnapshotLocally.
        if let range = name.range(of: #"_\d{9,}(\.\d+)?$"#, options: .regularExpression) {
            name.removeSubrange(range)
        }
        return name.contains(".") ? name : nil
    }

    private func bridgeString(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty { return value }
            if let value = dictionary[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }

    private func bridgeBool(_ dictionary: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = dictionary[key] as? Bool { return value }
            if let value = dictionary[key] as? NSNumber { return value.boolValue }
            if let value = dictionary[key] as? String {
                if ["true", "yes", "1"].contains(value.lowercased()) { return true }
                if ["false", "no", "0"].contains(value.lowercased()) { return false }
            }
        }
        return nil
    }

    private func bridgeDouble(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
