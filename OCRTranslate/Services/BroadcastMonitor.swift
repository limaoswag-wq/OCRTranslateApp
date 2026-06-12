import Foundation
import Combine

/// Monitors broadcast state and manages IPC with the Broadcast Upload Extension
class BroadcastMonitor: ObservableObject {
    static let shared = BroadcastMonitor()
    
    @Published var isBroadcasting = false
    @Published var lastOCRText: String = ""
    @Published var lastTranslatedText: String = ""
    @Published var lastUpdateTime: Date?
    
    private var fileWatcher: DispatchSourceFileSystemObject?
    private let appGroupID = "group.com.limaoswag.ocrtranslate"
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Shared Data Path
    
    var translationDataPath: URL? {
        sharedContainerURL?.appendingPathComponent("translation_data.json")
    }
    
    var controlPath: URL? {
        sharedContainerURL?.appendingPathComponent("control.json")
    }
    
    // MARK: - Read latest translation from extension
    
    func readLatestTranslation() -> TranslateResult? {
        guard let path = translationDataPath,
              let data = try? Data(contentsOf: path),
              let result = try? JSONDecoder().decode(TranslateResult.self, from: data) else {
            return nil
        }
        return result
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        guard let path = translationDataPath else { return }
        
        // Create the file if it doesn't exist
        if !FileManager.default.fileExists(atPath: path.path) {
            try? Data().write(to: path)
        }
        
        // Use a timer to poll for changes (more reliable than file watchers for App Groups)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollForUpdates()
        }
    }
    
    private func pollForUpdates() {
        guard let result = readLatestTranslation() else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if result.originalText != self.lastOCRText {
                self.lastOCRText = result.originalText
                self.lastTranslatedText = result.translatedText
                self.lastUpdateTime = result.timestamp
            }
        }
    }
    
    // MARK: - Control messages
    
    func sendStopCommand() {
        guard let path = controlPath else { return }
        let cmd = ["action": "stop"]
        try? JSONSerialization.data(withJSONObject: cmd).write(to: path)
    }
}
