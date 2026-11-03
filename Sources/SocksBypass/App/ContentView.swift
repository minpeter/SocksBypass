import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var model: RelayViewModel
    @State private var copiedID: String?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    warningCard
                    if case .listening(let port) = model.status {
                        addressCard(port: port)
                    }
                    credentialsCard
                    trafficCard
                    sessionsCard
                    activityCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("SocksBypass")
            .safeAreaInset(edge: .bottom) { controlButton }
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
            .sheet(isPresented: $showSettings) { SettingsSheet(model: model) }
        }
    }

    // MARK: Status

    private var statusInfo: (String, String, Color) {
        switch model.status {
        case .stopped: return ("중지됨", "stop.circle.fill", .gray)
        case .starting: return ("시작 중…", "hourglass.circle.fill", .orange)
        case .listening: return ("실행 중", "checkmark.circle.fill", .green)
        case .failed(let reason): return ("오류: \(reason)", "exclamationmark.octagon.fill", .red)
        }
    }

    private var statusCard: some View {
        let (title, icon, color) = statusInfo
        return card {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, isActive: model.status == .starting)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold())
                    Label(model.backgroundActive ? "백그라운드 유지 중 (잠금/닫아도 계속)" : "포그라운드에서만 동작",
                          systemImage: model.backgroundActive ? "moon.fill" : "sun.max")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    /// Always visible, never dismissible. Louder when auth is off.
    private var warningCard: some View {
        let open = !model.authEnabled
        let tint: Color = open ? .red : .orange
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: open ? "lock.open.trianglebadge.exclamationmark" : "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
            Text(open
                 ? "인증이 꺼져 있습니다(NO AUTH). 이 주소에 닿을 수 있는 누구나 이 휴대폰 회선으로 트래픽을 보낼 수 있습니다. 내 핫스팟에서만 쓰세요."
                 : "토큰이 있는 사람만 접속할 수 있지만 트래픽은 암호화되지 않습니다. 내 휴대폰 핫스팟처럼 직접 관리하는 네트워크에서만 켜세요.")
                .font(.footnote)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.4)))
    }

    private var credentialsCard: some View {
        card(title: "인증", icon: "key.fill") {
            if model.authEnabled {
                credentialRow("사용자", RelayViewModel.username, id: "user")
                credentialRow("토큰 (비밀번호)", model.token, id: "token")
                Text("리눅스에서 sbp up 첫 실행 때 이 토큰을 한 번 입력하면 저장됩니다.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("NO AUTH: 설정에서 꺼져 있음").font(.subheadline).foregroundStyle(.red)
            }
        }
    }

    private func credentialRow(_ label: String, _ value: String, id: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body.monospaced().weight(.semibold)).textSelection(.enabled)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = value
                copiedID = id
            } label: {
                Image(systemName: copiedID == id ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Address

    private func addressCard(port: UInt16) -> some View {
        card(title: "접속 주소", icon: "network") {
            if model.endpoints.isEmpty {
                Text("접속 가능한 주소가 없습니다. 핫스팟이나 Wi-Fi를 켜세요.")
                    .font(.subheadline).foregroundStyle(.orange)
            } else {
                ForEach(model.endpoints) { endpoint in
                    let text = "\(endpoint.address):\(String(port))"
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(roleLabel(endpoint.role)).font(.caption).foregroundStyle(.secondary)
                            Text(text).font(.title3.monospaced().weight(.semibold)).textSelection(.enabled)
                        }
                        Spacer()
                        Button {
                            UIPasteboard.general.string = text
                            copiedID = endpoint.id
                        } label: {
                            Label(copiedID == endpoint.id ? "복사됨" : "복사",
                                  systemImage: copiedID == endpoint.id ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            Text(model.authEnabled ? "SOCKS5 · 사용자/비밀번호 · CONNECT / UDP ASSOCIATE" : "SOCKS5 · 인증 없음 · CONNECT / UDP ASSOCIATE")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "HOTSPOT": return "핫스팟"
        case "WI-FI": return "Wi-Fi"
        default: return role
        }
    }

    // MARK: Traffic

    private var trafficCard: some View {
        card(title: "트래픽", icon: "arrow.up.arrow.down") {
            HStack(spacing: 12) {
                metric("업로드", ByteFormat.rate(model.uploadBytesPerSecond),
                       sub: "누적 \(ByteFormat.size(model.uploadBytes))", icon: "arrow.up", color: .blue)
                metric("다운로드", ByteFormat.rate(model.downloadBytesPerSecond),
                       sub: "누적 \(ByteFormat.size(model.downloadBytes))", icon: "arrow.down", color: .green)
            }
        }
    }

    private var sessionsCard: some View {
        card(title: "세션", icon: "point.3.connected.trianglepath.dotted") {
            HStack(spacing: 12) {
                metric("TCP", String(model.activeTCP), sub: nil, icon: "link", color: .purple)
                metric("UDP", String(model.activeUDP), sub: nil, icon: "dot.radiowaves.up.forward", color: .pink)
                metric("전체", String(model.activeTotal), sub: nil, icon: "sum", color: .indigo)
            }
        }
    }

    private var activityCard: some View {
        card(title: "활동 기록", icon: "list.bullet.rectangle") {
            if model.log.isEmpty {
                Text("아직 기록이 없습니다").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(model.log.reversed().prefix(15)) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.at, format: .dateTime.hour().minute().second())
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        Text(entry.text).font(.caption)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: Control

    private var controlButton: some View {
        Button {
            model.toggle()
        } label: {
            Label(model.isRunning ? "프록시 중지" : "프록시 시작",
                  systemImage: model.isRunning ? "stop.fill" : "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(model.isRunning ? .red : .accentColor)
        .disabled(model.isStopping)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: Building blocks

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func card<Content: View>(title: String, icon: String,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        card {
            Label(title, systemImage: icon).font(.subheadline.bold()).foregroundStyle(.secondary)
            content()
        }
    }

    private func metric(_ label: String, _ value: String, sub: String?, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon).font(.caption).foregroundStyle(color)
            Text(value).font(.title3.monospacedDigit().bold()).lineLimit(1).minimumScaleFactor(0.6)
            if let sub { Text(sub).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SettingsSheet: View {
    @ObservedObject var model: RelayViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("인증 사용 (권장)", isOn: $model.authEnabled)
                } footer: {
                    Text("끄면 NO AUTH로 동작합니다. 같은 네트워크의 누구나 접속할 수 있습니다.")
                }
                Section {
                    Button("새 토큰 생성", role: .destructive) { model.regenerateToken() }
                } footer: {
                    Text("기존 토큰으로 페어링된 기기는 다시 입력해야 합니다.")
                }
                Section("정보") {
                    LabeledContent("버전", value: RelayViewModel.appVersion)
                    LabeledContent("Bonjour", value: RelayViewModel.serviceType)
                    LabeledContent("상태 API", value: ":\(StatusServer.defaultPort)/status")
                }
            }
            .navigationTitle("설정")
            .toolbar { Button("완료") { dismiss() } }
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
