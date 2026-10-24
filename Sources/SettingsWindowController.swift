import AppKit

class SettingsWindowController: NSWindowController {
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 540),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Profile Switcher — Settings"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentViewController = SettingsViewController()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: -
class SettingsViewController: NSViewController {
    private let manager = ProfileManager.shared
    private var profiles: [Profile] = []
    
    private var tableView: NSTableView!
    private var statusLabel: NSTextField!
    private var editorContainer: NSStackView!
    
    // Row containers (NSStackView with [label, field, spacer])
    private var nameRow: NSStackView!
    private var modelRow: NSStackView!
    private var providerRow: NSStackView!
    private var ctxRow: NSStackView!
    private var catalogRowView: NSStackView!
    private var effortPicker: NSSegmentedControl!
    private var wsPicker: NSSegmentedControl!
    
    // Direct references to the inner text fields
    private var nameField: NSTextField!
    private var modelTextField: NSTextField!
    private var providerTextField: NSTextField!
    private var ctxTextField: NSTextField!
    private var catalogTextField: NSTextField!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 540))
        profiles = manager.profiles
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        reloadList()
    }
    
    private func buildUI() {
        let v = self.view
        
        // === Table ===
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 48
        tableView.target = self
        tableView.action = #selector(rowSelected)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        col.width = 540
        tableView.addTableColumn(col)
        tableView.dataSource = self
        tableView.delegate = self
        scroll.documentView = tableView
        v.addSubview(scroll)
        
        // === Buttons ===
        let addBtn = makeButton("Add", action: #selector(addProfile))
        let delBtn = makeButton("Delete", action: #selector(deleteProfile))
        let saveBtn = makeButton("Save", action: #selector(saveAll))
        saveBtn.keyEquivalent = "\r"
        
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        v.addSubview(addBtn); v.addSubview(delBtn); v.addSubview(saveBtn); v.addSubview(statusLabel)
        
        // === Separator ===
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(sep)
        
        // === Editor ===
        editorContainer = NSStackView()
        editorContainer.orientation = .vertical
        editorContainer.alignment = .leading
        editorContainer.spacing = 10
        editorContainer.translatesAutoresizingMaskIntoConstraints = false
        editorContainer.isHidden = true
        v.addSubview(editorContainer)
        
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: v.topAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            scroll.heightAnchor.constraint(equalToConstant: 160),
            
            addBtn.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            addBtn.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            delBtn.centerYAnchor.constraint(equalTo: addBtn.centerYAnchor),
            delBtn.leadingAnchor.constraint(equalTo: addBtn.trailingAnchor, constant: 8),
            saveBtn.centerYAnchor.constraint(equalTo: addBtn.centerYAnchor),
            saveBtn.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: addBtn.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: delBtn.trailingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: saveBtn.leadingAnchor, constant: -8),
            
            sep.topAnchor.constraint(equalTo: addBtn.bottomAnchor, constant: 10),
            sep.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            sep.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            sep.heightAnchor.constraint(equalToConstant: 1),
            
            editorContainer.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 10),
            editorContainer.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            editorContainer.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            editorContainer.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor, constant: -12)
        ])
        
        buildEditor()
    }
    
    private func makeButton(_ title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }
    
    private func buildEditor() {
        let title = NSTextField(labelWithString: "Edit Profile")
        title.font = .boldSystemFont(ofSize: 14)
        editorContainer.addArrangedSubview(title)
        
        nameRow = buildTextRow("Display Name", "ChatGPT", field: &nameField)
        modelRow = buildTextRow("Model", "o4-mini", field: &modelTextField)
        providerRow = buildTextRow("Provider", "empty = OpenAI", field: &providerTextField)
        ctxRow = buildTextRow("Context Window", "128000", field: &ctxTextField)
        catalogRowView = buildTextRow("Catalog JSON", "/path/to/models.json", field: &catalogTextField)
        
        // Effort segmented
        let effortRow = NSStackView()
        effortRow.orientation = .horizontal
        effortRow.spacing = 8
        effortRow.alignment = .firstBaseline
        let el = makeLabel("Reasoning")
        effortPicker = NSSegmentedControl(labels: ["min", "low", "med", "high"], trackingMode: .selectOne, target: nil, action: nil)
        effortPicker.selectedSegment = 3
        effortPicker.translatesAutoresizingMaskIntoConstraints = false
        effortRow.addArrangedSubview(el)
        effortRow.addArrangedSubview(effortPicker)
        effortRow.addArrangedSubview(NSView())
        
        // Web search segmented
        let wsRow = NSStackView()
        wsRow.orientation = .horizontal
        wsRow.spacing = 8
        wsRow.alignment = .firstBaseline
        let wl = makeLabel("Web Search")
        wsPicker = NSSegmentedControl(labels: ["on", "off"], trackingMode: .selectOne, target: nil, action: nil)
        wsPicker.selectedSegment = 0
        wsPicker.translatesAutoresizingMaskIntoConstraints = false
        wsRow.addArrangedSubview(wl)
        wsRow.addArrangedSubview(wsPicker)
        wsRow.addArrangedSubview(NSView())
        
        editorContainer.addArrangedSubview(nameRow)
        editorContainer.addArrangedSubview(modelRow)
        editorContainer.addArrangedSubview(providerRow)
        editorContainer.addArrangedSubview(effortRow)
        editorContainer.addArrangedSubview(ctxRow)
        editorContainer.addArrangedSubview(wsRow)
        editorContainer.addArrangedSubview(catalogRowView)
    }
    
    private func makeLabel(_ text: String) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = .secondaryLabelColor
        lbl.widthAnchor.constraint(equalToConstant: 120).isActive = true
        return lbl
    }
    
    private func buildTextRow(_ label: String, _ placeholder: String, field: inout NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline
        
        let lbl = makeLabel(label)
        
        let f = NSTextField(string: "")
        f.placeholderString = placeholder
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: 300).isActive = true
        f.target = self
        f.action = #selector(fieldEdited(_:))
        
        row.addArrangedSubview(lbl)
        row.addArrangedSubview(f)
        row.addArrangedSubview(NSView())
        
        field = f
        return row
    }
    
    @objc private func fieldEdited(_ sender: NSTextField) {
        updateCatalogVisibility()
    }
    
    // MARK: - Actions
    @objc private func addProfile() {
        let n = profiles.count + 1
        profiles.append(Profile(
            name: "p\(n)", displayName: "New \(n)", model: "o4-mini",
            modelProvider: nil, modelCatalogJson: nil,
            modelReasoningEffort: "high", modelContextWindow: 128000,
            modelAutoCompactTokenLimit: 115200, webSearch: "enabled", extraLines: []
        ))
        reloadList()
        if !profiles.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: profiles.count - 1), byExtendingSelection: false)
            showEditor(at: profiles.count - 1)
        }
    }
    
    @objc private func deleteProfile() {
        let idx = tableView.selectedRow
        guard idx >= 0, idx < profiles.count else { return }
        profiles.remove(at: idx)
        reloadList()
        let ni = tableView.selectedRow
        if ni >= 0 { showEditor(at: ni) }
        else { editorContainer.isHidden = true }
    }
    
    @objc private func saveAll() {
        syncEditor()
        manager.updateProfiles(profiles)
        manager.saveProfiles()
        statusLabel.stringValue = "✓ Saved"
        statusLabel.textColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.statusLabel.stringValue = ""
        }
    }
    
    @objc private func rowSelected() {
        let idx = tableView.selectedRow
        if idx >= 0, idx < profiles.count {
            showEditor(at: idx)
        } else {
            editorContainer.isHidden = true
        }
    }
    
    // MARK: - Editor logic
    private func showEditor(at index: Int) {
        guard index < profiles.count else { return }
        let p = profiles[index]
        editorContainer.isHidden = false
        
        nameField.stringValue = p.displayName
        modelTextField.stringValue = p.model
        providerTextField.stringValue = p.modelProvider ?? ""
        ctxTextField.stringValue = String(p.modelContextWindow ?? 128000)
        catalogTextField.stringValue = p.modelCatalogJson ?? ""
        
        let efforts = ["minimal", "low", "medium", "high"]
        if let e = p.modelReasoningEffort, let seg = efforts.firstIndex(of: e) {
            effortPicker.selectedSegment = seg
        }
        wsPicker.selectedSegment = (p.webSearch == "disabled") ? 1 : 0
        updateCatalogVisibility()
    }
    
    private func syncEditor() {
        let idx = tableView.selectedRow
        guard idx >= 0, idx < profiles.count else { return }
        
        let efforts = ["minimal", "low", "medium", "high"]
        let seg = effortPicker.selectedSegment
        profiles[idx].displayName = nameField.stringValue
        profiles[idx].model = modelTextField.stringValue
        let prov = providerTextField.stringValue
        profiles[idx].modelProvider = prov.isEmpty ? nil : prov
        profiles[idx].modelContextWindow = Int(ctxTextField.stringValue) ?? 128000
        profiles[idx].modelReasoningEffort = seg >= 0 ? efforts[seg] : "high"
        profiles[idx].webSearch = (wsPicker.selectedSegment == 1) ? "disabled" : "enabled"
        let cat = catalogTextField.stringValue
        profiles[idx].modelCatalogJson = cat.isEmpty ? nil : cat
    }
    
    private func updateCatalogVisibility() {
        let prov = providerTextField?.stringValue ?? ""
        catalogRowView?.isHidden = (prov != "splash")
    }
    
    private func reloadList() {
        tableView?.reloadData()
    }
}

// MARK: - Table
extension SettingsViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        profiles.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let p = profiles[row]
        var text = "\(p.displayName)\nmodel: \(p.model)"
        if let prov = p.modelProvider {
            text += "\nprovider: \(prov)"
        }
        
        let cell = NSTextField(wrappingLabelWithString: text)
        cell.font = .systemFont(ofSize: 11)
        cell.isEditable = false
        cell.isSelectable = false
        cell.maximumNumberOfLines = 3
        cell.lineBreakMode = .byWordWrapping
        if p.name == manager.currentProfileName {
            cell.textColor = .linkColor
        }
        return cell
    }
}
