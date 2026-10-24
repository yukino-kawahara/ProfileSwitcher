import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var settingsWindowController: SettingsWindowController?
    let manager = ProfileManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }
    
    // MARK: - Status Item
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "⇄ \(manager.menuBarTitle)"
            button.toolTip = "Profile Switcher (\(manager.currentProfileName ?? "unknown"))"
        }
        
        rebuildMenu()
    }
    
    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Header
        let headerItem = NSMenuItem(title: "Profile: \(manager.currentProfile?.displayName ?? "Unknown")", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())
        
        // Profile options
        for profile in manager.profiles {
            let item = NSMenuItem(
                title: profile.displayName,
                action: #selector(selectProfile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile.name
            
            // Checkmark for current
            if profile.name == manager.currentProfileName {
                item.state = .on
            }
            
            menu.addItem(item)
        }
        
        menu.addItem(.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Relaunch with current profile
        let relaunchItem = NSMenuItem(title: "Relaunch ChatGPT", action: #selector(relaunchChatGPT), keyEquivalent: "r")
        relaunchItem.target = self
        menu.addItem(relaunchItem)
        
        menu.addItem(.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Profile Switcher", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Actions
    @objc func selectProfile(_ sender: NSMenuItem) {
        guard let profileName = sender.representedObject as? String else { return }
        
        // If already on this profile, just relaunch
        if profileName == manager.currentProfileName {
            let alert = NSAlert()
            alert.messageText = "Already on \(profileName)"
            alert.informativeText = "Relaunching ChatGPT…"
            alert.alertStyle = .informational
            alert.runModal()
            relaunchChatGPT()
            return
        }
        
        // Confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Switch to \(profileName)?"
        alert.informativeText = "ChatGPT will be restarted with this profile."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Switch")
        alert.addButton(withTitle: "Cancel")
        
        // Disable menu during operation
        statusItem.menu = nil
        
        let response = alert.runModal()
        
        if response == .cancel {
            // Rebuild menu
            setupStatusItem()
            return
        }
        
        // Perform switch
        let result = manager.fullSwitch(to: profileName, relaunch: true)
        
        // Show result
        let resultAlert = NSAlert()
        if case .success(let msg) = result {
            resultAlert.messageText = "✓ \(msg)"
        } else if case .failure(let error) = result {
            resultAlert.messageText = "✗ Switch Failed"
            resultAlert.informativeText = error.localizedDescription
            resultAlert.alertStyle = .warning
        }
        resultAlert.runModal()
        
        // Rebuild
        setupStatusItem()
    }
    
    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }
    
    @objc func relaunchChatGPT() {
        manager.quitChatGPT()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.manager.launchChatGPT()
        }
    }
    
    @objc func quit() {
        NSApp.terminate(nil)
    }
}
