import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var model: RelayViewModel
    @State private var copiedID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    warningCard
                    if case .listening(let port) = model.status {
                        addressCard(port: port)
                    }
                    trafficCard
                    sessionsCard
                    activityCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("SocksBypass")
            .safeAreaInset(edge: .bottom) { controlButton }
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

    /// Always visible, never dismissible: the proxy is unauthenticated.
    private var warningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("비밀번호가 없는 프록시입니다. 이 주소에 닿을 수 있는 누구나 사용할 수 있으니, 내 휴대폰 핫스팟처럼 직접 관리하는 네트워크에서만 켜세요.")
                .font(.footnote)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.4)))
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
            Text("SOCKS5 · 인증 없음 · CONNECT / UDP ASSOCIATE")
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
