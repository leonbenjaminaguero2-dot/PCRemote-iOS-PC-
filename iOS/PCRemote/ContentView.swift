import SwiftUI

struct ContentView: View {
    @StateObject private var pc = RemoteClient()
    @State private var tab = "Control"
    @State private var showSettings = false
    @State private var search = ""
    @State private var apps: [RemoteApp] = []
    @State private var screen: UIImage?
    @State private var typed = ""
    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.065, blue: 0.085).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("PCRemote").font(.system(size: 23, weight: .bold))
                    Spacer()
                    Circle().fill(pc.connected ? .green : .orange).frame(width: 8, height: 8)
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill").padding(10) }
                }.padding(.horizontal, 16)
                HStack(spacing: 8) {
                    nav("Control", "gamecontroller.fill"); nav("Screen", "display"); nav("Apps", "square.grid.2x2.fill")
                }.padding(12)
                if tab == "Control" { controls }
                else if tab == "Screen" { screenView }
                else { appsView }
                Spacer(minLength: 0)
            }
        }.preferredColorScheme(.dark).sheet(isPresented: $showSettings) {
            NavigationStack {
                Form {
                    TextField("Dirección del PC", text: $pc.host).textInputAutocapitalization(.never).keyboardType(.URL)
                    SecureField("PIN", text: $pc.pin).keyboardType(.numberPad)
                    Button("Probar conexión") { Task { await pc.test() } }
                    Text(pc.connected ? "Conectado" : "Sin conexión")
                }.navigationTitle("Ajustes").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Listo") { showSettings = false } } }
            }
        }.task { await pc.test() }
    }
    func nav(_ name: String, _ icon: String) -> some View {
        Button { tab = name; if name == "Apps" { Task { await loadApps() } }; if name == "Screen" { Task { await loadScreen() } } } label: {
            Label(name, systemImage: icon).frame(maxWidth: .infinity).padding(12)
                .background(tab == name ? .blue.opacity(0.8) : .white.opacity(0.08))
        }.buttonStyle(.plain)
    }
    var controls: some View {
        VStack(spacing: 22) {
            Text("CONTROL").font(.caption.bold()).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                keyButton("chevron.up", "UP")
                HStack(spacing: 8) { keyButton("chevron.left", "LEFT"); keyButton("circle.fill", "ENTER"); keyButton("chevron.right", "RIGHT") }
                keyButton("chevron.down", "DOWN")
            }
            HStack(spacing: 12) {
                Button("ESC") { Task { await pc.send("/api/input/key", KeyPayload(key: "ESC")) } }
                Button("⏯") { Task { await pc.send("/api/input/key", KeyPayload(key: "SPACE")) } }
                Button("↵") { Task { await pc.send("/api/input/key", KeyPayload(key: "ENTER")) } }
            }.buttonStyle(.borderedProminent)
            Divider()
            Text("Ratón y teclado").font(.headline)
            HStack {
                Button("Clic") { Task { await pc.send("/api/input/mouse", MousePayload(x: 500, y: 400, click: true)) } }
                TextField("Escribí texto para el PC", text: $typed).textFieldStyle(.roundedBorder)
                Button("Enviar") { Task { await pc.send("/api/input/text", TextPayload(text: typed)); typed = "" } }
            }.buttonStyle(.bordered)
        }.padding(18)
    }
    func keyButton(_ icon: String, _ key: String) -> some View {
        Button { Task { await pc.send("/api/input/key", KeyPayload(key: key)) } } label: {
            Image(systemName: icon).font(.title2).frame(width: 58, height: 50).background(.white.opacity(0.12))
        }.buttonStyle(.plain)
    }
    var screenView: some View {
        VStack {
            if let screen { Image(uiImage: screen).resizable().scaledToFit().padding() }
            else { ContentUnavailableView("Pantalla del PC", systemImage: "display", description: Text("Actualizá para ver la captura")) }
            Button("Actualizar pantalla") { Task { await loadScreen() } }.buttonStyle(.borderedProminent)
        }.padding()
    }
    var appsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Aplicaciones").font(.title2.bold()); Spacer(); Button { Task { await loadApps() } } label: { Image(systemName: "plus").padding(10).background(.blue) } }
            TextField("Buscar aplicaciones", text: $search).textFieldStyle(.roundedBorder).onChange(of: search) { _, _ in Task { await loadApps() } }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(apps) { app in
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "app.fill").font(.largeTitle).foregroundStyle(.blue)
                            Text(app.name).font(.headline).lineLimit(2)
                            Button("Abrir") { Task { await pc.send("/api/apps/open", OpenPayload(path: app.path)) } }.buttonStyle(.borderedProminent)
                        }.padding(14).frame(width: 160, height: 145, alignment: .leading).background(.white.opacity(0.07))
                    }
                }
            }
            Spacer()
        }.padding(16)
    }
    @MainActor func loadApps() async {
        do { let (d, _) = try await pc.request("/api/apps?search=" + (search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")); apps = try JSONDecoder().decode([RemoteApp].self, from: d) } catch { apps = [] }
    }
    @MainActor func loadScreen() async {
        do { let (d, _) = try await pc.request("/api/screen"); screen = UIImage(data: d) } catch { screen = nil }
    }
}
struct RemoteApp: Codable, Identifiable { var id: String; var name: String; var path: String }
