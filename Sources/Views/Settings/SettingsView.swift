import SwiftUI

public struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "Tối"
    @AppStorage("appStoreCountry") private var appStoreCountry = "VN"
    @AppStorage("defaultPaymentMode") private var defaultPaymentMode = PaymentMode.appStore.rawValue
    @AppStorage("noCacheMode") private var noCacheMode = false

    @ObservedObject private var store = StoreKitService.shared
    @ObservedObject private var bridge = TweakBridge.shared
    @State private var showingCountryPicker = false
    @State private var showingPaymentPicker = false
    @State private var alertMessage: String?

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Cài đặt")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(.iappayTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 46)

                    settingsSection("Giao diện") {
                        settingsRow(icon: "moon", color: .iappayAccent, title: "Chế độ") {
                            Picker("", selection: $appearanceMode) {
                                Text("Tự động").tag("Tự động")
                                Text("Sáng").tag("Sáng")
                                Text("Tối").tag("Tối")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 190)
                        }
                    }
                    Text("Chế độ Tự động sẽ tuân theo thiết lập giao diện Sáng/Tối của hệ điều hành iOS.")
                        .font(.system(size: 13))
                        .foregroundColor(.iappayTextSecondary)
                        .padding(.horizontal, 4)

                    settingsSection("Cửa hàng & quốc gia") {
                        Button { showingCountryPicker = true } label: {
                            settingsRowContent(icon: "globe", color: .iappayAccent, title: "Quốc gia App Store", value: appStoreCountry, chevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection("Phương thức thanh toán") {
                        Button { showingPaymentPicker = true } label: {
                            settingsRowContent(icon: "creditcard.fill", color: .iappayGreen, title: "Chế độ mua", value: defaultPaymentMode == PaymentMode.appStore.rawValue ? "App Store (Chính thức)" : defaultPaymentMode, chevron: true)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.iappayBorder)
                        settingsRowContent(icon: "clock.arrow.circlepath", color: .iappayTextSecondary, title: "Đồng bộ gần nhất", value: bridge.lastSyncDate.map(Self.dateFormatter.string) ?? "Chưa đồng bộ")
                        Divider().overlay(Color.iappayBorder)
                        Button {
                            UserDefaults.standard.removeObject(forKey: "appStoreSearchHistory")
                            alertMessage = "Đã xóa lịch sử tìm kiếm."
                        } label: {
                            settingsRowContent(icon: "trash.fill", color: .iappayOrange, title: "Xóa lịch sử tìm kiếm", value: nil)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("• App Store: hiện sheet xác nhận mua chính thức của Apple (StoreKit).\n• Apple Sandbox: dùng StoreKit Test hoặc tài khoản Sandbox.\n• Direct: gửi lệnh tới companion bridge khi app đích đang chạy.")
                        .font(.system(size: 13))
                        .foregroundColor(.iappayTextSecondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)

                    settingsSection("Dữ liệu & bộ nhớ tạm") {
                        settingsRow(icon: "archive", color: .iappayOrange, title: "No-Cache Mode") {
                            Toggle("", isOn: $noCacheMode)
                                .labelsHidden()
                                .tint(.iappayGreen)
                        }
                        Divider().overlay(Color.iappayBorder)
                        Button { store.clearCachedCatalog(); alertMessage = "Đã xóa cache catalog IAP." } label: {
                            settingsRowContent(icon: "archivebox.fill", color: .iappayOrange, title: "Xóa cache catalog IAP", value: "\(store.items.count) gói", titleColor: .iappayYellow)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.iappayBorder)
                        Button {
                            let json = UIPasteboard.general.string ?? ""
                            alertMessage = store.importCatalogJSON(json)
                                ? "Đã nhập catalog từ clipboard."
                                : "Clipboard không chứa catalog JSON hợp lệ."
                        } label: {
                            settingsRowContent(icon: "doc.on.clipboard", color: .iappayCyan, title: "Nhập catalog JSON từ clipboard", value: nil)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.iappayBorder)
                        Button { bridge.clearCache(); alertMessage = "Đã xóa snapshot và dữ liệu bridge." } label: {
                            settingsRowContent(icon: "exclamationmark.octagon.fill", color: .iappayRed, title: "Xóa sạch toàn bộ data & reset", value: nil, titleColor: .iappayRed)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.iappayBorder)
                        Button { alertMessage = "Cache hình ảnh do URLSession/AsyncImage quản lý theo chính sách hệ thống." } label: {
                            settingsRowContent(icon: "image", color: .iappayAccent, title: "Xóa cache hình ảnh", value: nil, titleColor: .iappayYellow)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Catalog được cache sau lần tải thành công đầu tiên để tránh gọi App Store liên tục. No-Cache Mode luôn đọc lại snapshot từ bridge.")
                        .font(.system(size: 13))
                        .foregroundColor(.iappayTextSecondary)
                        .padding(.horizontal, 4)

                    settingsSection("Thông tin phát triển") {
                        settingsRowContent(icon: "grid", color: .iappayCyan, title: "NappStore", value: "v1.0.0 (build 2026)")
                        Divider().overlay(Color.iappayBorder)
                        settingsRowContent(icon: "users", color: .iappayAccent, title: "Đội ngũ", value: "ctdoteam")
                        Divider().overlay(Color.iappayBorder)
                        settingsRowContent(icon: "chevron.left.forwardslash.chevron.right", color: .iappayGreen, title: "Lập trình viên", value: "dothanh1110")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(Color.iappayBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .confirmationDialog("Chọn quốc gia App Store", isPresented: $showingCountryPicker, titleVisibility: .visible) {
                ForEach(["VN", "US", "JP", "KR"], id: \.self) { code in
                    Button(code) { appStoreCountry = code }
                }
                Button("Hủy", role: .cancel) {}
            }
            .confirmationDialog("Chọn chế độ mua", isPresented: $showingPaymentPicker, titleVisibility: .visible) {
                ForEach(PaymentMode.allCases) { mode in
                    Button(mode.rawValue) { defaultPaymentMode = mode.rawValue }
                }
                Button("Hủy", role: .cancel) {}
            }
            .alert("NappStore", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).sectionLabelStyle()
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.iappayCard))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.iappayBorder.opacity(0.7), lineWidth: 0.5))
        }
    }

    private func settingsIcon(_ icon: String, color: Color) -> some View {
        GlyphView(sf: icon, size: 16, color: .white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
    }

    private func settingsRow<Accessory: View>(icon: String, color: Color, title: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 13) {
            settingsIcon(icon, color: color)
            Text(title).font(.system(size: 16)).foregroundColor(.iappayTextPrimary)
            Spacer()
            accessory()
        }
        .padding(.vertical, 9)
    }

    private func settingsRowContent(icon: String, color: Color, title: String, value: String? = nil, chevron: Bool = false, titleColor: Color = .iappayTextPrimary) -> some View {
        HStack(spacing: 13) {
            settingsIcon(icon, color: color)
            Text(title).font(.system(size: 16)).foregroundColor(titleColor)
            Spacer()
            if let value { Text(value).font(.system(size: 15)).foregroundColor(.iappayTextSecondary).lineLimit(1) }
            if chevron { GlyphView(.chevronRight, size: 13, color: .iappayTextMuted) }
        }
        .padding(.vertical, 9)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()
}
