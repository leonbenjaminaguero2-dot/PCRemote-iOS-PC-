import Foundation
import UIKit

@MainActor final class RemoteClient: ObservableObject {
    @Published var host = UserDefaults.standard.string(forKey: "host") ?? "http://192.168.1.100:8765" {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }
    @Published var pin = UserDefaults.standard.string(forKey: "pin") ?? "4826" {
        didSet { UserDefaults.standard.set(pin, forKey: "pin") }
    }
    @Published var connected = false
    func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> (Data, URLResponse) {
        guard let url = URL(string: host.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) else { throw URLError(.badURL) }
        var r = URLRequest(url: url); r.httpMethod = method; r.httpBody = body; r.timeoutInterval = 8
        r.setValue(pin, forHTTPHeaderField: "X-PCRemote-Pin")
        if body != nil { r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return try await URLSession.shared.data(for: r)
    }
    func send<T: Encodable>(_ path: String, _ value: T) async {
        if let body = try? JSONEncoder().encode(value) { _ = try? await request(path, method: "POST", body: body) }
    }
    func test() async { do { _ = try await request("/api/status"); connected = true } catch { connected = false } }
}
struct KeyPayload: Encodable { let key: String }
struct MousePayload: Encodable { let x: Int; let y: Int; let click: Bool }
struct OpenPayload: Encodable { let path: String }
struct TextPayload: Encodable { let text: String }
