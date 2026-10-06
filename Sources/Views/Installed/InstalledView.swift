import SwiftUI

public struct InstalledView: View {
    @ObservedObject private var scanner = InstalledAppsScanner.shared
    @ObservedObject private var store = StoreKitService.shared
    @ObservedObject private var bridge = TweakBridge.shared

    @State private var query = ""
    @State private var selectedSegment = 0
    @State private var catalogFilter = 0
    @State private var selectedApp: InstalledAppInfo?
    @State private var showingLogs = false
    @State private var showScanAllConfirm = false

    private var apps: [InstalledAppInfo] {
        allApps.filter { app in
            let segmentMatches = selectedSegment == 0 ? !app.isSystemApp : app.isSystemApp
            guard segmentMatches else { return false }
            let snapshot = bridge.latestSnapshot(for: app.bundleId)
            switch catalogFilter {
            case 1:
                guard (snapshot?.totalFreeTrials ?? 0) > 0 else { return false }
            case 2:
                guard (snapshot?.totalProducts ?? 0) > 0 else { return false }
            case 3:
                guard snapshot == nil else { return false }
            default:
                break
            }
            guard !query.isEmpty else { return true }
            return app.appName.localizedCaseInsensitiveContains(query) || app.bundleId.localizedCaseInsensitiveContains(query)
        }
    }

    private var allApps: [InstalledAppInfo] {
        var byBundle = Dictionary(uniqueKeysWithValues: store.catalogAppInfos.map { ($0.bundleId, $0) })
        // Prefer the live installation metadata when the system scanner can
        // provide it; catalog-only apps still remain available for inspection.
        for app in scanner.installedApps { byBundle[app.bundleId] = app }
        return byBundle.values.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    private var userApps: [InstalledAppInfo] { allApps.filter { !$0.isSystemApp } }
    private var trialAppsCount: Int { allApps.filter { (bridge.latestSnapshot(for: $0.bundleId)?.totalFreeTrials ?? 0) > 0 }.count }
    private var iapAppsCount: Int { allApps.filter { (bridge.latestSnapshot(for: $0.bundleId)?.totalProducts ?? 0) > 0 }.count }
    private var unscannedCount: Int { allApps.filter { bridge.latestSnapshot(for: $0.bundleId) == nil }.count }

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if bridge.isBatchScanning {
                        HStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.iappayAccent)
                            Text(bridge.batchScanStatus)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.iappayTextSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .referenceCard(cornerRadius: 14)
                    }
                    SearchField("Filter by name or bundle ID", text: $query)
                    segmentControl
                    catalogFilterPills

                    if scanner.isScanning {
                        ProgressView("Đang quét ứng dụng…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .tint(.iappayAccent)
                    } else if apps.isEmpty {
                        emptyState
                    } else {
                        Text(selectedSegment == 0 ? "\(apps.count) User Applications" : "\(apps.count) System Applications")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.iappayTextSecondary)
                            .padding(.top, 8)
                        VStack(spacing: 12) {
                            ForEach(apps) { app in
                                Button { selectedApp = app } label: { appRow(app) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color.iappayBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedApp) { app in
                AppIAPDetailView(
                    appName: app.appName,
                    bundleId: app.bundleId,
                    appIconSystem: icon(for: app.bundleId),
                    initialItems: store.items.filter { $0.appBundleId == app.bundleId }
                )
            }
            .sheet(isPresented: $showingLogs) { LogsView() }
            .confirmationDialog("Quét IAP toàn bộ app?", isPresented: $showScanAllConfirm, titleVisibility: .visible) {
                Button("Quét \(userApps.count) app (mở lần lượt app chưa rõ ID)") {
                    bridge.requestWholeDeviceScan(apps: userApps, launchSequentially: true)
                }
                Button("Chỉ xếp lệnh quét (không mở app)") {
                    bridge.requestWholeDeviceScan(apps: userApps, launchSequentially: false)
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Cần tweak IAPCheck đang hoạt động. App có product ID đã biết được quét ngay qua daemon; app còn lại sẽ được tweak bắt catalog khi chạy.")
            }
            .onAppear {
                if scanner.installedApps.isEmpty { scanner.scanApps(includeSystem: selectedSegment == 1) }
                if store.items.isEmpty { store.loadRealData() }
                bridge.loadAllSnapshots()
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Đã cài đặt")
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(.iappayTextPrimary)
            HStack(spacing: 10) {
                Spacer()
                Button {
                    showScanAllConfirm = true
                } label: {
                    GlyphView(.scan, size: 18, color: .iappayAccent)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.iappayCardRaised))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.iappayBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                Button {
                    scanner.scanApps(includeSystem: selectedSegment == 1)
                    store.loadRealData()
                    bridge.loadAllSnapshots()
                } label: {
                    GlyphView(.refresh, size: 18, color: .iappayAccent)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.iappayCardRaised))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.iappayBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 46)
    }

    private var segmentControl: some View {
        HStack(spacing: 0) {
            segmentButton("User (\(allApps.filter { !$0.isSystemApp }.count))", index: 0)
            segmentButton("System (\(allApps.filter(\.isSystemApp).count))", index: 1)
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.iappayCardRaised))
    }

    private var catalogFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "Tất cả", isSelected: catalogFilter == 0) { catalogFilter = 0 }
                FilterPill(title: "★ Có trial (\(trialAppsCount))", isSelected: catalogFilter == 1) { catalogFilter = 1 }
                FilterPill(title: "Có IAP (\(iapAppsCount))", isSelected: catalogFilter == 2) { catalogFilter = 2 }
                FilterPill(title: "Chưa quét (\(unscannedCount))", isSelected: catalogFilter == 3) { catalogFilter = 3 }
            }
        }
    }

    private func segmentButton(_ title: String, index: Int) -> some View {
        Button {
            selectedSegment = index
            if index == 1 && !scanner.installedApps.contains(where: \.isSystemApp) { scanner.scanApps(includeSystem: true) }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selectedSegment == index ? .semibold : .regular))
                .foregroundColor(selectedSegment == index ? .white : .iappayTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selectedSegment == index ? Color.iappayBorder : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(selectedSegment == index ? 0.08 : 0), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func scanApp(_ app: InstalledAppInfo) {
        let ids = store.catalogProductIds(for: app.bundleId)
        if ids.isEmpty {
            // No seed ids: let the tweak inside the target app harvest its
            // receipt and whatever the app itself queries after launch.
            bridge.requestCatalogScan(bundleId: app.bundleId, autoLaunch: true)
        } else {
            // Known ids: resolve the catalog through the daemon spoof right
            // away, and still queue the direct entry for the app's next run.
            bridge.requestProxyScan(bundleId: app.bundleId, productIds: ids)
            bridge.requestCatalogScan(bundleId: app.bundleId, productIds: ids, autoLaunch: false)
        }
    }

    private func appRow(_ app: InstalledAppInfo) -> some View {
        HStack(spacing: 13) {
            AppIconView(systemName: icon(for: app.bundleId), size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(app.appName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.iappayTextPrimary)
                    .lineLimit(1)
                Text("v\(app.version) • \(app.bundleId)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.iappayTextSecondary)
                    .lineLimit(1)
                if let snapshot = bridge.latestSnapshot(for: app.bundleId) {
                    HStack(spacing: 6) {
                        BadgeTag("\(snapshot.totalProducts) IAP", bg: .iappayCardRaised)
                        if snapshot.totalFreeTrials > 0 {
                            BadgeTag("★ \(snapshot.totalFreeTrials) Trial", bg: .iappayGreen)
                        }
                        if snapshot.totalDiscounts > 0 {
                            BadgeTag("\(snapshot.totalDiscounts) Giảm giá", bg: .iappayYellow, fg: .black)
                        }
                    }
                }
            }
            Spacer()
            Button {
                scanApp(app)
            } label: {
                GlyphView(.scan, size: 16, color: .iappayAccent)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.iappayCardRaised))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.iappayBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            GlyphView(.chevronRight, size: 15, color: .iappayTextMuted)
        }
        .padding(14)
        .referenceCard(cornerRadius: 13)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            GlyphView(.layers, size: 38, color: .iappayTextMuted)
            Text("Không tìm thấy ứng dụng")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.iappayTextPrimary)
            Text("Cài tweak IAPCheck để bắt catalog StoreKit, sau đó nhấn nút tia sét để quét hoặc mở app đích để tweak tự ghi snapshot.")
                .font(.system(size: 13))
                .foregroundColor(.iappayTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func icon(for bundleID: String) -> String {
        let lower = bundleID.lowercased()
        if lower.contains("lemon") { return "video.fill" }
        if lower.contains("openai") { return "bubble.left.and.bubble.right.fill" }
        if lower.contains("duolingo") { return "bird.fill" }
        if lower.contains("canva") { return "paintpalette.fill" }
        if lower.contains("apple") { return "gearshape.fill" }
        return "app.fill"
    }
}
