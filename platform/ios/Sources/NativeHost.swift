import SwiftUI
import UniformTypeIdentifiers
import UIKit

private struct GameFile: Identifiable {
    let url: URL
    let displayName: String
    let bundleIdentifier: String?
    let orientationCapabilities: UInt32
    let icon: UIImage?

    var id: String { url.path }

    func launchOrientation(
        override orientation: Int,
        currentInterfaceOrientation: UIInterfaceOrientation
    ) -> Int {
        let supportsPortrait = orientationCapabilities & 1 != 0
        let supportsLandscape = orientationCapabilities & 2 != 0
        if supportsPortrait && !supportsLandscape {
            return 0
        }
        if supportsLandscape && !supportsPortrait {
            if orientation == 1 || orientation == 2 {
                return orientation
            }
            return currentInterfaceOrientation == .landscapeRight ? 2 : 1
        }
        if orientation == 1 || orientation == 2 {
            return orientation
        }
        switch currentInterfaceOrientation {
        case .landscapeLeft:
            return 1
        case .landscapeRight:
            return 2
        default:
            return 0
        }
    }
}

@MainActor
private final class GameLibrary: ObservableObject {
    @Published var games: [GameFile] = []
    @Published var importError: String?
    @Published var launchError: String?
    @Published var isLaunching = false

    let appsDirectory: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        appsDirectory = documents.appendingPathComponent("touchHLE_apps", isDirectory: true)
        migrateLegacyNetworkSetting(in: documents)
        reload()
    }

    func reload() {
        do {
            try FileManager.default.createDirectory(
                at: appsDirectory,
                withIntermediateDirectories: true
            )
            games = try FileManager.default.contentsOfDirectory(
                at: appsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { ["ipa", "app"].contains($0.pathExtension.lowercased()) }
            .map(gameFile(from:))
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    func importGame(from sourceURL: URL) {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try FileManager.default.createDirectory(
                at: appsDirectory,
                withIntermediateDirectories: true
            )
            let destinationURL = uniqueDestination(for: sourceURL.lastPathComponent)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            reload()
        } catch {
            importError = error.localizedDescription
        }
    }

    func delete(_ game: GameFile) {
        do {
            try FileManager.default.removeItem(at: game.url)
            reload()
        } catch {
            importError = error.localizedDescription
        }
    }

    func launch(
        _ game: GameFile,
        scaleHack: Int,
        orientation: Int,
        networkAccess: Bool,
        analogTilt: Bool
    ) {
        isLaunching = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            let launchOrientation = game.launchOrientation(
                override: orientation,
                currentInterfaceOrientation: TouchHLENativeHost.currentInterfaceOrientation
            )
            TouchHLENativeHost.hideHostWindow()
            TouchHLENativeHost.prepareGameControls(
                launchOrientation: launchOrientation
            ) { [weak self] in
                guard let self else { return }
                let result = game.url.path.withCString { path in
                    touchhle_ios_launch_game(
                        path,
                        Int32(scaleHack),
                        Int32(launchOrientation),
                        networkAccess ? 1 : 0,
                        analogTilt ? 1 : 0
                    )
                }

                TouchHLENativeHost.hideGameControls()
                TouchHLENativeHost.restoreHostWindow()
                self.isLaunching = false
                if result != 0 {
                    self.launchError = "touchHLE could not start this game. The diagnostic log has been saved in Files."
                }
            }
        }
    }

    private func uniqueDestination(for fileName: String) -> URL {
        let original = appsDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: original.path) else {
            return original
        }

        let source = URL(fileURLWithPath: fileName)
        let stem = source.deletingPathExtension().lastPathComponent
        let fileExtension = source.pathExtension
        var index = 2

        while true {
            let candidateName = fileExtension.isEmpty
                ? "\(stem) \(index)"
                : "\(stem) \(index).\(fileExtension)"
            let candidate = appsDirectory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func gameFile(from url: URL) -> GameFile {
        let fallbackName = url.deletingPathExtension().lastPathComponent
        guard let metadata = url.path.withCString({ touchhle_ios_game_metadata_create($0) }) else {
            return GameFile(
                url: url,
                displayName: fallbackName,
                bundleIdentifier: nil,
                orientationCapabilities: 1,
                icon: nil
            )
        }
        defer { touchhle_ios_game_metadata_free(metadata) }

        let metadataDisplayName = touchhle_ios_game_metadata_display_name(metadata)
            .map { String(cString: $0) } ?? fallbackName
        let displayName = preferredDisplayName(
            metadataName: metadataDisplayName,
            fallbackName: fallbackName
        )
        let bundleIdentifier = touchhle_ios_game_metadata_bundle_identifier(metadata)
            .map { String(cString: $0) }
        let orientationCapabilities = touchhle_ios_game_metadata_orientation_capabilities(metadata)

        return GameFile(
            url: url,
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            orientationCapabilities: orientationCapabilities,
            icon: gameIcon(from: metadata)
        )
    }

    private func preferredDisplayName(metadataName: String, fallbackName: String) -> String {
        let metadataIsAbbreviated = metadataName.contains("...") || metadataName.contains("…")
        let fallbackIsComplete = !fallbackName.contains("...") && !fallbackName.contains("…")
        guard metadataIsAbbreviated, fallbackIsComplete else { return metadataName }

        return fallbackName.replacingOccurrences(of: "_", with: " ")
    }

    private func gameIcon(from metadata: OpaquePointer) -> UIImage? {
        let width = Int(touchhle_ios_game_metadata_icon_width(metadata))
        let height = Int(touchhle_ios_game_metadata_icon_height(metadata))
        guard width > 0,
              height > 0,
              let pixels = touchhle_ios_game_metadata_icon_rgba(metadata)
        else {
            return nil
        }

        let data = Data(bytes: pixels, count: width * height * 4)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: [
                    CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    .byteOrder32Big
                ],
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              )
        else {
            return nil
        }

        return UIImage(cgImage: image)
    }

    private func migrateLegacyNetworkSetting(in documents: URL) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "networkAccess") == nil else { return }

        let legacyURL = documents.appendingPathComponent(".touchHLE_network_access")
        guard let value = try? String(contentsOf: legacyURL, encoding: .utf8) else { return }
        defaults.set(value.trimmingCharacters(in: .whitespacesAndNewlines) == "enabled", forKey: "networkAccess")
    }
}

private final class GameControlsWindow: UIWindow {
    weak var interactiveView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let interactiveView,
              hitView === interactiveView || hitView.isDescendant(of: interactiveView)
        else {
            return nil
        }
        return hitView
    }
}

private final class GameControlsViewController: UIViewController {
    var allowedOrientations: UIInterfaceOrientationMask = .portrait
    var onExit: (() -> Void)?

    private(set) lazy var exitButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) {
            configuration = .glass()
        } else {
            configuration = .gray()
        }
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 19, weight: .bold)
        configuration.image = UIImage(
            systemName: "rectangle.portrait.and.arrow.right",
            withConfiguration: symbolConfiguration
        )?.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = .systemRed
        button.configuration = configuration
        button.tintColor = .systemRed
        button.accessibilityLabel = "Exit Game"
        button.accessibilityHint = "Stops the game and returns to your library"
        button.addTarget(self, action: #selector(exitGame), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var fpsIndicator: UIButton = {
        let indicator = UIButton(type: .system)
        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) {
            configuration = .glass()
        } else {
            configuration = .gray()
        }
        configuration.title = "— FPS"
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = .systemYellow
        indicator.configuration = configuration
        indicator.isUserInteractionEnabled = false
        indicator.accessibilityLabel = "Frame rate"
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private var fpsTimer: Timer?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        allowedOrientations
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(exitButton)

        NSLayoutConstraint.activate([
            exitButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            exitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            exitButton.widthAnchor.constraint(equalToConstant: 48),
            exitButton.heightAnchor.constraint(equalToConstant: 48)
        ])

        guard UserDefaults.standard.bool(forKey: "showFPSOverlay") else { return }

        view.addSubview(fpsIndicator)
        NSLayoutConstraint.activate([
            fpsIndicator.centerYAnchor.constraint(equalTo: exitButton.centerYAnchor),
            fpsIndicator.trailingAnchor.constraint(equalTo: exitButton.leadingAnchor, constant: -8),
            fpsIndicator.heightAnchor.constraint(equalToConstant: 48)
        ])

        updateFPS()
        fpsTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(updateFPS),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(fpsTimer!, forMode: .common)
    }

    deinit {
        fpsTimer?.invalidate()
    }

    @objc private func exitGame() {
        exitButton.isEnabled = false
        onExit?()
    }

    @objc private func updateFPS() {
        let fps = touchhle_ios_current_fps()
        fpsIndicator.configuration?.title = fps > 0 ? "\(Int(fps.rounded())) FPS" : "— FPS"
        fpsIndicator.accessibilityValue = fps > 0 ? "\(Int(fps.rounded())) frames per second" : "Unavailable"
    }
}

@objc(TouchHLENativeHost)
final class TouchHLENativeHost: NSObject {
    private static let shared = TouchHLENativeHost()
    private var window: UIWindow?
    private var gameControlsWindow: GameControlsWindow?

    @MainActor
    static var currentInterfaceOrientation: UIInterfaceOrientation {
        shared.window?.windowScene?.interfaceOrientation ?? .portrait
    }

    @MainActor
    @objc class func start() {
        shared.presentLibrary()
    }

    @MainActor
    static func restoreHostWindow() {
        guard let window = shared.window else { return }
        window.makeKeyAndVisible()
        if #available(iOS 16.0, *) {
            window.windowScene?.requestGeometryUpdate(
                .iOS(interfaceOrientations: .portrait)
            )
        }
    }

    @MainActor
    static func hideHostWindow() {
        shared.window?.isHidden = true
    }

    @MainActor
    static func prepareGameControls(
        launchOrientation: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        shared.presentGameControls(
            launchOrientation: launchOrientation,
            completion: completion
        )
    }

    @MainActor
    static func hideGameControls() {
        shared.dismissGameControls()
    }

    @MainActor
    private func presentLibrary() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: LibraryView())
        window.tintColor = .systemBlue
        window.makeKeyAndVisible()
        self.window = window
    }

    @MainActor
    private func presentGameControls(
        launchOrientation: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        guard gameControlsWindow == nil,
              let windowScene = window?.windowScene
        else {
            completion()
            return
        }

        let controlsWindow = GameControlsWindow(windowScene: windowScene)
        controlsWindow.windowLevel = UIWindow.Level.normal + 3
        controlsWindow.accessibilityIdentifier = "touchHLE.gameControls"
        controlsWindow.backgroundColor = .clear

        let viewController = GameControlsViewController()
        let launchOrientationMask: UIInterfaceOrientationMask
        switch launchOrientation {
        case 1:
            launchOrientationMask = .landscapeLeft
        case 2:
            launchOrientationMask = .landscapeRight
        default:
            launchOrientationMask = .portrait
        }
        viewController.allowedOrientations = launchOrientationMask
        viewController.onExit = { [weak self] in
            self?.returnToLibrary()
        }

        controlsWindow.rootViewController = viewController
        viewController.loadViewIfNeeded()
        controlsWindow.interactiveView = viewController.exitButton
        controlsWindow.isHidden = false
        viewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        gameControlsWindow = controlsWindow

        if #available(iOS 16.0, *) {
            windowScene.requestGeometryUpdate(
                .iOS(interfaceOrientations: launchOrientationMask)
            )
        }
        waitForGameSurface(
            windowScene: windowScene,
            orientationMask: launchOrientationMask,
            expectsLandscape: launchOrientation == 1 || launchOrientation == 2,
            remainingAttempts: 30,
            completion: completion
        )
    }

    @MainActor
    private func waitForGameSurface(
        windowScene: UIWindowScene,
        orientationMask: UIInterfaceOrientationMask,
        expectsLandscape: Bool,
        remainingAttempts: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        let bounds = windowScene.coordinateSpace.bounds
        let hasExpectedShape = expectsLandscape
            ? bounds.width > bounds.height
            : bounds.height >= bounds.width
        let hasExpectedOrientation = expectsLandscape
            ? windowScene.interfaceOrientation.isLandscape
            : windowScene.interfaceOrientation.isPortrait

        if (hasExpectedShape && hasExpectedOrientation) || remainingAttempts == 0 {
            gameControlsWindow?.frame = bounds
            gameControlsWindow?.layoutIfNeeded()
            if let viewController = gameControlsWindow?.rootViewController as? GameControlsViewController {
                viewController.allowedOrientations = orientationMask
                viewController.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            print(
                "touchHLE game surface ready: orientation=\(windowScene.interfaceOrientation.rawValue) " +
                "bounds=\(Int(bounds.width))x\(Int(bounds.height))"
            )
            DispatchQueue.main.async {
                completion()
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.waitForGameSurface(
                windowScene: windowScene,
                orientationMask: orientationMask,
                expectsLandscape: expectsLandscape,
                remainingAttempts: remainingAttempts - 1,
                completion: completion
            )
        }
    }

    @MainActor
    private func dismissGameControls() {
        gameControlsWindow?.isHidden = true
        gameControlsWindow?.rootViewController = nil
        gameControlsWindow = nil
    }

    @MainActor
    @objc private func returnToLibrary() {
        touchhle_ios_request_exit()
    }
}

private struct LibraryView: View {
    @StateObject private var library = GameLibrary()
    @State private var showingImporter = false
    @State private var showingSettings = false
    @State private var showingAbout = false
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("scaleHack") private var scaleHack = 3
    @AppStorage("orientation") private var orientation = 0
    @AppStorage("networkAccess") private var networkAccess = false
    @AppStorage("analogTilt") private var analogTilt = true

    private static let ipaType = UTType(filenameExtension: "ipa") ?? .archive

    var body: some View {
        NavigationStack {
            ZStack {
                LibraryBackground()

                if library.games.isEmpty {
                    ContentUnavailableView {
                        Label("No Games Yet", systemImage: "gamecontroller")
                    } description: {
                        Text("Import a 32-bit iPhone game to add it to your library.")
                    }
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(library.games) { game in
                                GameCard(game: game) {
                                    library.launch(
                                        game,
                                        scaleHack: scaleHack,
                                        orientation: orientation,
                                        networkAccess: networkAccess,
                                        analogTilt: analogTilt
                                    )
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        library.delete(game)
                                    } label: {
                                        Label("Remove from Library", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 110)
                    }
                    .refreshable {
                        library.reload()
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAbout = true
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    EnableJITButton()

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import Game", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .touchHLEImportButtonStyle()
                .padding(.bottom, 8)
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [Self.ipaType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        library.importGame(from: url)
                    }
                case .failure(let error):
                    library.importError = error.localizedDescription
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .alert("Couldn’t Import Game", isPresented: errorBinding(for: $library.importError)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(library.importError ?? "Unknown error")
            }
            .alert("Game Couldn’t Start", isPresented: errorBinding(for: $library.launchError)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(library.launchError ?? "Unknown error")
            }
            .overlay {
                if library.isLaunching {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Starting game…")
                            .font(.headline)
                    }
                    .padding(24)
                    .touchHLELaunchOverlayStyle()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                library.reload()
            }
        }
    }

    private func errorBinding(for error: Binding<String?>) -> Binding<Bool> {
        Binding(
            get: { error.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    error.wrappedValue = nil
                }
            }
        )
    }
}

private struct EnableJITButton: View {
    @Environment(\.openURL) private var openURL
    @State private var showingUnavailableAlert = false

    var body: some View {
        Button {
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                showingUnavailableAlert = true
                return
            }

            var components = URLComponents()
            components.scheme = "stikdebug"
            components.host = "enable-jit"
            components.queryItems = [
                URLQueryItem(name: "bundle-id", value: bundleIdentifier),
                URLQueryItem(name: "script-name", value: "universal.js")
            ]
            guard let url = components.url else {
                showingUnavailableAlert = true
                return
            }

            openURL(url) { accepted in
                if !accepted {
                    showingUnavailableAlert = true
                }
            }
        } label: {
            Label("Enable JIT", systemImage: "bolt.fill")
        }
        .accessibilityHint("Opens StikDebug and enables JIT for touchHLE")
        .alert("StikDebug Not Available", isPresented: $showingUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Install and configure StikDebug, then try again. LocalDevVPN must be connected.")
        }
    }
}

private extension View {
    @ViewBuilder
    func touchHLEImportButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(.blue).interactive(), in: Capsule())
        } else {
            background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(.blue.opacity(0.2), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func touchHLELaunchOverlayStyle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
        }
    }
}

private struct LibraryBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.13),
                    Color.clear,
                    Color.indigo.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct GameCard: View {
    let game: GameFile
    let launch: () -> Void

    var body: some View {
        Button(action: launch) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .indigo.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if let icon = game.icon {
                        Image(uiImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 82, height: 82)
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    } else {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }
                .frame(height: 112)

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.displayName)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Tap to play")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(game.displayName)
        .accessibilityHint("Starts this game in touchHLE")
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("scaleHack") private var scaleHack = 3
    @AppStorage("orientation") private var orientation = 0
    @AppStorage("networkAccess") private var networkAccess = false
    @AppStorage("analogTilt") private var analogTilt = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Picker("Resolution Scale", selection: $scaleHack) {
                        Text("Off").tag(1)
                        Text("2×").tag(2)
                        Text("3×").tag(3)
                        Text("4×").tag(4)
                    }

                    Picker("Starting Orientation", selection: $orientation) {
                        Text("Automatic").tag(0)
                        Text("Landscape Left").tag(1)
                        Text("Landscape Right").tag(2)
                    }
                }

                Section {
                    Toggle("Network Access", isOn: $networkAccess)
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("Some games need network access. Leave this off unless a game requires it.")
                }

                Section("Controls") {
                    Toggle("Analog Sticks Control Tilt", isOn: $analogTilt)
                }

                Section {
                    EnableJITButton()
                } header: {
                    Text("JIT")
                } footer: {
                    Text("JIT must be enabled again whenever touchHLE starts as a new app process.")
                }

                Section("Advanced") {
                    NavigationLink {
                        DeveloperToolsView()
                    } label: {
                        Label("Developer Tools", systemImage: "wrench.and.screwdriver")
                    }
                }

                Section {
                    Text("Settings apply the next time you start a game.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct DeveloperToolsView: View {
    @AppStorage("showFPSOverlay") private var showFPSOverlay = false

    var body: some View {
        Form {
            Section {
                Toggle("Show FPS During Games", isOn: $showFPSOverlay)
            } header: {
                Text("Performance")
            } footer: {
                Text("Displays a small frame-rate counter beside the exit button. This is intended for testing and is off by default.")
            }
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let iconName = iconFiles.last
        else {
            return nil
        }

        return UIImage(named: iconName)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        Group {
                            if let appIcon {
                                Image(uiImage: appIcon)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "iphone.gen3")
                                    .font(.system(size: 42, weight: .medium))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Text("touchHLE")
                            .font(.title2.bold())
                        Text("Experimental iOS Port • touchHLE 0.2.3")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }

                Section("About") {
                    Text("touchHLE runs older 32-bit iPhone applications without including any Apple software. This native port is an experimental community project and is not an official touchHLE release.")

                    Link(destination: URL(string: "https://appdb.touchhle.org/")!) {
                        Label("Game Compatibility", systemImage: "checkmark.seal")
                    }

                    Link(destination: URL(string: "https://touchhle.org/")!) {
                        Label("touchHLE Website", systemImage: "safari")
                    }

                    Link(destination: URL(string: "https://github.com/touchHLE/touchHLE")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
