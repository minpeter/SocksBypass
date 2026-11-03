import SwiftUI
import UIKit

/// Geist-like palette: monochrome, 1px hairlines, no shadows or gradients.
private enum G {
    static let fg = Color.primary
    static let muted = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.63, alpha: 1) : UIColor(white: 0.40, alpha: 1) })
    static let border = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.15, alpha: 1) : UIColor(white: 0.92, alpha: 1) })
    static let subtle = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.04, alpha: 1) : UIColor(white: 0.98, alpha: 1) })
    static let bg = Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
    static let green = Color(red: 0, green: 0.67, blue: 0.47)
    static let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    static let radius: CGFloat = 10
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("GeistMono-" + face(weight), size: size) }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("Geist-" + face(weight), size: size) }
    private static func face(_ weight: Font.Weight) -> String {
        switch weight {
        case .semibold, .bold, .heavy, .black: return "SemiBold"
        case .medium: return "Medium"
        default: return "Regular"
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: RelayViewModel
    @State private var copiedID: String?
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                statusLine.padding(.bottom, 8)
                if case .listening(let port) = model.status { addressCard(port: port) }
                credentialsCard
                metricsGrid
                warning
                activity
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(G.bg.ignoresSafeArea())
        .foregroundStyle(G.fg)
        .safeAreaInset(edge: .bottom) { controlButton }
        .sheet(isPresented: $showSettings) { SettingsSheet(model: model) }
    }

    // MARK: Header / status

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hotline").font(G.sans(28, .semibold)).tracking(-1)
                Text("v\(RelayViewModel.appVersion)").font(G.mono(12)).foregroundStyle(G.muted)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 15)).foregroundStyle(G.muted)
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(G.border, lineWidth: 1))
            }
        }
        .padding(.bottom, 8)
    }

    private var statusInfo: (String, Color) {
        switch model.status {
        case .stopped: return ("중지됨", G.muted)
        case .starting: return ("시작 중", G.muted)
        case .listening: return ("실행 중", G.green)
        case .failed(let reason): return ("오류 · \(reason)", G.red)
        }
    }

    private var statusLine: some View {
        let (text, color) = statusInfo
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(G.sans(14, .medium))
            if model.isRunning {
                Text(model.backgroundActive ? "· 백그라운드 유지" : "· 포그라운드에서만")
                    .font(G.sans(14)).foregroundStyle(G.muted)
            }
        }
    }

    // MARK: Cards

    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(G.sans(12)).tracking(0.6).foregroundStyle(G.muted)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: G.radius).stroke(G.border, lineWidth: 1))
    }

    private var hairline: some View { Rectangle().fill(G.border).frame(height: 1) }

    private func addressCard(port: UInt16) -> some View {
        card("주소") {
            if model.endpoints.isEmpty {
                Text("접속 가능한 주소가 없습니다. 핫스팟이나 Wi-Fi를 켜세요.")
                    .font(G.sans(13)).foregroundStyle(G.muted)
            } else {
                ForEach(Array(model.endpoints.enumerated()), id: \.element.id) { index, endpoint in
                    if index > 0 { hairline }
                    copyRow(roleLabel(endpoint.role), "\(endpoint.address):\(String(port))", id: endpoint.id, size: 18)
                }
            }
        }
    }

    private var credentialsCard: some View {
        card("인증") {
            if model.authEnabled {
                VStack(alignment: .leading, spacing: 2) {
                    Text("사용자").font(G.sans(12)).foregroundStyle(G.muted)
                    Text(RelayViewModel.username).font(G.mono(15))
                }
                copyRow("토큰", model.token, id: "token", size: 15)
            } else {
                HStack(spacing: 8) {
                    Circle().fill(G.red).frame(width: 8, height: 8)
                    Text("NO AUTH · 설정에서 꺼짐").font(G.mono(14))
                }
            }
        }
    }

    private func copyRow(_ label: String, _ value: String, id: String, size: CGFloat) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(G.sans(12)).foregroundStyle(G.muted)
                Text(value).font(G.mono(size, .medium)).textSelection(.enabled).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = value
                copiedID = id
            } label: {
                Text(copiedID == id ? "복사됨" : "복사").font(G.sans(13, .medium)).foregroundStyle(G.fg)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(G.border, lineWidth: 1))
            }
        }
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "HOTSPOT": return "핫스팟"
        case "WI-FI": return "Wi-Fi"
        default: return role
        }
    }

    private var metricsGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell("↑ 업로드", ByteFormat.rate(model.uploadBytesPerSecond), ByteFormat.size(model.uploadBytes))
                Rectangle().fill(G.border).frame(width: 1)
                cell("↓ 다운로드", ByteFormat.rate(model.downloadBytesPerSecond), ByteFormat.size(model.downloadBytes))
            }
            hairline
            HStack(spacing: 0) {
                cell("TCP", String(model.activeTCP), nil)
                Rectangle().fill(G.border).frame(width: 1)
                cell("UDP", String(model.activeUDP), nil)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(RoundedRectangle(cornerRadius: G.radius).stroke(G.border, lineWidth: 1))
    }

    private func cell(_ label: String, _ value: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(G.sans(12)).foregroundStyle(G.muted)
            Text(value).font(G.mono(18, .medium)).lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
            if let sub { Text(sub).font(G.mono(12)).foregroundStyle(G.muted) }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Always visible, never dismissible. Red text only when NO AUTH is on.
    private var warning: some View {
        let open = !model.authEnabled
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(open ? G.red : G.fg)
            Text(open
                 ? "인증이 꺼져 있습니다. 이 주소에 닿는 누구나 이 회선을 쓸 수 있습니다. 내 핫스팟에서만 사용하세요."
                 : "트래픽은 암호화되지 않습니다. 직접 관리하는 핫스팟에서만 사용하세요.")
                .font(G.sans(13)).foregroundStyle(open ? G.red : G.muted)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(G.subtle, in: RoundedRectangle(cornerRadius: G.radius))
        .overlay(RoundedRectangle(cornerRadius: G.radius).stroke(open ? G.red.opacity(0.5) : G.border, lineWidth: 1))
    }

    private var activity: some View {
        card("활동") {
            if model.log.isEmpty {
                Text("—").font(G.mono(12)).foregroundStyle(G.muted)
            } else {
                ForEach(model.log.reversed().prefix(8)) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(entry.at, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
                            .font(G.mono(11)).foregroundStyle(G.muted)
                        Text(entry.text).font(G.mono(12))
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: Control

    private var controlButton: some View {
        Button { model.toggle() } label: {
            Text(model.isRunning ? "정지" : "시작")
                .font(G.sans(16, .semibold))
                .foregroundStyle(G.bg)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(G.fg, in: RoundedRectangle(cornerRadius: G.radius))
        }
        .disabled(model.isStopping)
        .opacity(model.isStopping ? 0.5 : 1)
        .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 8)
        .background(G.bg)
    }
}

private struct SettingsSheet: View {
    @ObservedObject var model: RelayViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("인증 사용 (권장)", isOn: $model.authEnabled).tint(G.fg)
                } footer: {
                    Text("끄면 NO AUTH로 동작합니다. 같은 네트워크의 누구나 접속할 수 있습니다.")
                }
                Section {
                    Button("새 토큰 생성", role: .destructive) { model.regenerateToken() }
                } footer: {
                    Text("기존 토큰으로 페어링된 기기는 다시 입력해야 합니다.")
                }
                Section("정보") {
                    LabeledContent("버전") { Text(RelayViewModel.appVersion).font(G.mono(14)) }
                    LabeledContent("Bonjour") { Text(RelayViewModel.serviceType).font(G.mono(14)) }
                    LabeledContent("상태 API") { Text(":\(StatusServer.defaultPort)/status").font(G.mono(14)) }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("완료") { dismiss() }.tint(G.fg) }
        }
    }
}

enum ByteFormat {
    static func size(_ bytes: UInt64) -> String {
        format(Double(bytes), units: ["B", "KB", "MB", "GB", "TB"])
    }

    static func rate(_ bytesPerSecond: UInt64) -> String {
        format(Double(bytesPerSecond), units: ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"])
    }

    private static func format(_ value: Double, units: [String]) -> String {
        var value = value
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return index == 0
            ? "\(Int(value)) \(units[0])"
            : String(format: "%.1f %@", value, units[index])
    }
}
