import AppKit
import Foundation

// MARK: - Profile Definition
struct Profile: Codable {
    var name: String
    var displayName: String
    var model: String
    var modelProvider: String?
    var modelCatalogJson: String?
    var modelReasoningEffort: String?
    var modelContextWindow: Int?
    var modelAutoCompactTokenLimit: Int?
    var webSearch: String?
    var extraLines: [String]
}

// MARK: - ProfileManager
class ProfileManager {
    static let shared = ProfileManager()
    
    let appSupportDir: URL
    let profilesFile: URL
    let configFile: URL
    let chatGPTBundleID = "com.openai.codex"
    let chatGPTPath = "/Applications/ChatGPT.app"
    
    private(set) var profiles: [Profile] = []
    private(set) var currentProfileName: String?
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        appSupportDir = home.appendingPathComponent("Library/Application Support/ProfileSwitcher")
        profilesFile = appSupportDir.appendingPathComponent("profiles.json")
        configFile = home.appendingPathComponent(".codex/config.toml")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        
        loadProfiles()
        detectCurrentProfile()
    }
    
    // MARK: - Load/Save
    func loadProfiles() {
        guard FileManager.default.fileExists(atPath: profilesFile.path) else {
            profiles = Self.defaultProfiles()
            saveProfiles()
            return
        }
        do {
            let data = try Data(contentsOf: profilesFile)
            profiles = try JSONDecoder().decode([Profile].self, from: data)
        } catch {
            NSLog("ProfileSwitcher: Failed to load profiles: \(error)")
            profiles = Self.defaultProfiles()
            saveProfiles()
        }
    }
    
    func updateProfiles(_ newProfiles: [Profile]) {
        profiles = newProfiles
    }

    func saveProfiles() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(profiles)
            try data.write(to: profilesFile)
        } catch {
            NSLog("ProfileSwitcher: Failed to save profiles: \(error)")
        }
    }
    
    static func defaultProfiles() -> [Profile] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            Profile(
                name: "chatgpt",
                displayName: "ChatGPT",
                model: "o4-mini",
                modelProvider: nil,
                modelCatalogJson: nil,
                modelReasoningEffort: "high",
                modelContextWindow: 128000,
                modelAutoCompactTokenLimit: 115200,
                webSearch: "live",
                extraLines: []
            ),
            Profile(
                name: "splash",
                displayName: "Splash (Local)",
                model: "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M",
                modelProvider: "splash",
                modelCatalogJson: home + "/Library/Application Support/Splash/chatgpt/models.json",
                modelReasoningEffort: "low",
                modelContextWindow: 65536,
                modelAutoCompactTokenLimit: 58982,
                webSearch: "disabled",
                extraLines: [
                    "[model_providers.splash]",
                    "name = \"Splash (Local)\"",
                    "base_url = \"http://127.0.0.1:8000/v1\"",
                    "wire_api = \"responses\"",
                    "requires_openai_auth = false",
                    "supports_websockets = false"
                ]
            )
        ]
    }
    
    // MARK: - Current Profile Detection
    func detectCurrentProfile() {
        guard let content = try? String(contentsOf: configFile, encoding: .utf8) else { return }
        
        let hasSplashProvider = content.contains("model_provider = \"splash\"")
        let hasSplashSection = content.contains("[model_providers.splash]")
        
        if hasSplashProvider || hasSplashSection {
            currentProfileName = "splash"
        } else {
            currentProfileName = "chatgpt"
        }
    }
    
    // MARK: - Switch Profile
    @discardableResult
    func switchProfile(to profileName: String) -> Result<String, Error> {
        guard let profile = profiles.first(where: { $0.name == profileName }) else {
            return .failure(ProfileSwitcherError.profileNotFound(profileName))
        }
        
        guard var content = try? String(contentsOf: configFile, encoding: .utf8) else {
            return .failure(ProfileSwitcherError.configFileNotFound)
        }
        
        // Backup
        let backupPath = configFile.deletingLastPathComponent()
            .appendingPathComponent("config.toml.bak-profileswitcher")
        try? FileManager.default.copyItem(at: configFile, to: backupPath)
        
        // Modify config
        content = modifyConfig(content: content, profile: profile)
        
        // Write config
        do {
            try content.write(to: configFile, atomically: true, encoding: .utf8)
        } catch {
            return .failure(ProfileSwitcherError.writeFailed(error.localizedDescription))
        }
        
        // Record current profile
        currentProfileName = profileName
        let stateFile = appSupportDir.appendingPathComponent("current-profile")
        try? profileName.write(to: stateFile, atomically: true, encoding: .utf8)
        
        return .success("Switched to \(profile.displayName)")
    }
    
    private func modifyConfig(content: String, profile: Profile) -> String {
        var lines = content.components(separatedBy: "\n")
        
        // Remove existing model-related lines
        let keysToRemove = ["model", "model_provider", "model_catalog_json",
                           "model_reasoning_effort", "model_context_window",
                           "model_auto_compact_token_limit", "web_search"]
        
        for key in keysToRemove {
            let indices = lines.indices.filter { i in
                lines[i].hasPrefix(key + " =") || lines[i].hasPrefix(key + "=")
            }
            for i in indices.reversed() {
                lines.remove(at: i)
            }
        }
        
        // Remove [model_providers.splash] section if exists
        if let startIdx = lines.firstIndex(where: { $0.hasPrefix("[model_providers.splash]") }) {
            var endIdx = startIdx + 1
            while endIdx < lines.count {
                let line = lines[endIdx]
                if line.hasPrefix("[") && line.hasSuffix("]") { break }
                endIdx += 1
            }
            lines.removeSubrange(startIdx..<endIdx)
        }
        
        // Insert new model settings at the top
        var newLines: [String] = []
        if let effort = profile.modelReasoningEffort {
            newLines.append("model_reasoning_effort = \"\(effort)\"")
        }
        if let ctx = profile.modelContextWindow {
            newLines.append("model_context_window = \(ctx)")
        }
        if let compact = profile.modelAutoCompactTokenLimit {
            newLines.append("model_auto_compact_token_limit = \(compact)")
        }
        if let ws = profile.webSearch {
            newLines.append("web_search = \"\(ws)\"")
        }
        newLines.append("model = \"\(profile.model)\"")
        if let provider = profile.modelProvider {
            newLines.append("model_provider = \"\(provider)\"")
        }
        if let catalog = profile.modelCatalogJson {
            newLines.append("model_catalog_json = \"\(catalog)\"")
        }
        newLines.append("")
        
        lines.insert(contentsOf: newLines, at: 0)
        
        // Append extra lines at the end
        if !profile.extraLines.isEmpty {
            lines.append("")
            lines.append(contentsOf: profile.extraLines)
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - App Management
    func quitChatGPT() {
        let runningApp = NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == chatGPTBundleID }
        if let runningApp {
            runningApp.terminate()
            let start = Date()
            while NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == chatGPTBundleID }) {
                if Date().timeIntervalSince(start) > 5 { break }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    func launchChatGPT() {
        let url = URL(fileURLWithPath: chatGPTPath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                NSLog("ProfileSwitcher: Failed to launch ChatGPT: \(error)")
            }
        }
    }
    
    func fullSwitch(to profileName: String, relaunch: Bool = true) -> Result<String, Error> {
        if relaunch {
            quitChatGPT()
        }
        
        let result = switchProfile(to: profileName)
        
        if relaunch, case .success = result {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.launchChatGPT()
            }
        }
        
        return result
    }
    
    // MARK: - Current Profile Info
    var currentProfile: Profile? {
        guard let name = currentProfileName else { return nil }
        return profiles.first(where: { $0.name == name })
    }
    
    var menuBarTitle: String {
        switch currentProfileName {
        case "chatgpt": return "C"
        case "splash": return "S"
        default: return "?"
        }
    }
}

// MARK: - Errors
enum ProfileSwitcherError: Error, LocalizedError {
    case profileNotFound(String)
    case configFileNotFound
    case writeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound(let name): return "Profile not found: \(name)"
        case .configFileNotFound: return "Config file not found: ~/.codex/config.toml"
        case .writeFailed(let msg): return "Failed to write config: \(msg)"
        }
    }
}
