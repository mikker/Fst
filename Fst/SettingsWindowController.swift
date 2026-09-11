import AppKit

final class SettingsWindowController: NSWindowController {
    private let lightPicker = NSPopUpButton()
    private let darkPicker = NSPopUpButton()
    private let fontPicker = NSPopUpButton()
    private let sizeField = NSTextField()
    private let heightField = NSTextField()
    private let wrapButton = NSButton(checkboxWithTitle: "Wrap lines to window width", target: nil, action: nil)
    private let lineNumbersButton = NSButton(checkboxWithTitle: "Show line numbers", target: nil, action: nil)
    private let defaultButton = NSButton(title: "Make Fst the Default Editor", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private let progress = NSProgressIndicator()
    private let themeStatus = NSTextField(wrappingLabelWithString: "")
    private var preferencesObserver: NSObjectProtocol?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        super.init(window: window)

        func row(_ label: String, _ control: NSView, suffix: String = "") -> NSStackView {
            let text = NSTextField(labelWithString: label)
            text.widthAnchor.constraint(equalToConstant: 125).isActive = true
            let row = NSStackView(views: [text, control, NSTextField(labelWithString: suffix)])
            row.orientation = .horizontal
            row.spacing = 12
            control.setAccessibilityLabel(label)
            return row
        }
        lightPicker.widthAnchor.constraint(equalToConstant: 250).isActive = true
        darkPicker.widthAnchor.constraint(equalToConstant: 250).isActive = true
        lightPicker.addItems(withTitles: EditorTheme.lightNames)
        lightPicker.selectItem(withTitle: EditorPreferences.lightTheme)
        darkPicker.addItems(withTitles: EditorTheme.darkNames)
        darkPicker.selectItem(withTitle: EditorPreferences.darkTheme)
        fontPicker.addItems(withTitles: ["System Mono"] + NSFontManager.shared.availableFontFamilies.sorted())
        fontPicker.selectItem(withTitle: EditorPreferences.fontName)
        fontPicker.widthAnchor.constraint(equalToConstant: 250).isActive = true
        for picker in [lightPicker, darkPicker, fontPicker] {
            picker.target = self
            picker.action = #selector(changePreferences(_:))
        }
        for (field, value, minimum, maximum) in [(sizeField, EditorPreferences.fontSize, 6, 48), (heightField, EditorPreferences.lineHeight, 80, 240)] {
            let format = NumberFormatter()
            format.minimum = NSNumber(value: minimum)
            format.maximum = NSNumber(value: maximum)
            format.maximumFractionDigits = 0
            field.formatter = format
            field.doubleValue = value
            field.widthAnchor.constraint(equalToConstant: 60).isActive = true
            field.target = self
            field.action = #selector(changePreferences(_:))
        }
        wrapButton.state = EditorPreferences.wrapLines ? .on : .off
        wrapButton.target = self
        wrapButton.action = #selector(changePreferences(_:))
        lineNumbersButton.state = EditorPreferences.showLineNumbers ? .on : .off
        lineNumbersButton.target = self
        lineNumbersButton.action = #selector(changePreferences(_:))
        let folderButton = NSButton(title: "Open Themes Folder", target: self, action: #selector(openThemesFolder(_:)))
        let reloadButton = NSButton(title: "Reload Themes", target: self, action: #selector(reloadThemes(_:)))
        let themeActions = NSStackView(views: [folderButton, reloadButton])
        themeActions.spacing = 8
        themeStatus.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        themeStatus.textColor = .secondaryLabelColor
        let preferenceRows = [row("Light appearance", lightPicker), row("Dark appearance", darkPicker),
                              themeActions, themeStatus,
                              row("Font", fontPicker), row("Font size", sizeField, suffix: "pt"),
                              row("Line height", heightField, suffix: "%"), row("Line wrapping", wrapButton),
                              row("Line numbers", lineNumbersButton)]

        let title = NSTextField(labelWithString: "Default editor")
        title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        let description = NSTextField(wrappingLabelWithString: "Open supported code files in Fst when you double-click them in Finder.")
        description.textColor = .secondaryLabelColor
        defaultButton.bezelStyle = .rounded
        defaultButton.target = self
        defaultButton.action = #selector(makeDefault(_:))
        defaultButton.toolTip = DefaultEditor.extensions.sorted().map { ".\($0)" }.joined(separator: ", ")
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        let actionRow = NSStackView(views: [defaultButton, progress])
        actionRow.orientation = .horizontal
        actionRow.spacing = 10
        status.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let stack = NSStackView(views: preferenceRows + [title, description, actionRow, status])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(24, after: preferenceRows.last!)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 28),
            description.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            themeStatus.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        preferencesObserver = NotificationCenter.default.addObserver(forName: .editorPreferencesChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncDisplayPreferences() }
        }
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { if let preferencesObserver { NotificationCenter.default.removeObserver(preferencesObserver) } }

    override func showWindow(_ sender: Any?) {
        reloadThemes(nil)
        super.showWindow(sender)
    }

    @objc private func openThemesFolder(_ sender: Any?) {
        do {
            _ = try CustomThemes.files()
            NSWorkspace.shared.open(CustomThemes.directory)
        } catch { themeStatus.stringValue = error.localizedDescription }
    }

    @objc private func reloadThemes(_ sender: Any?) {
        CustomThemes.reload()
        var files: [String] = []
        var failures: [String] = []
        do {
            for filename in try CustomThemes.files() {
                do { _ = try CustomThemes.load(filename: filename); files.append(filename) }
                catch { failures.append("\(filename): \(error.localizedDescription)") }
            }
        } catch { failures.append(error.localizedDescription) }
        for (picker, builtins, selection) in [(lightPicker, EditorTheme.lightNames, EditorPreferences.lightTheme),
                                               (darkPicker, EditorTheme.darkNames, EditorPreferences.darkTheme)] {
            picker.removeAllItems()
            for name in builtins {
                picker.addItem(withTitle: name)
                picker.lastItem?.representedObject = name
            }
            for filename in files {
                picker.addItem(withTitle: filename)
                picker.lastItem?.representedObject = "file:" + filename
            }
            if let item = picker.itemArray.first(where: { ($0.representedObject as? String) == selection }) {
                picker.select(item)
            } else if selection.hasPrefix("file:") {
                picker.addItem(withTitle: String(selection.dropFirst(5)) + " (unavailable)")
                picker.lastItem?.representedObject = selection
                picker.select(picker.lastItem)
            }
        }
        themeStatus.stringValue = failures.isEmpty
            ? "Add VS Code theme JSON files to the folder, then reload."
            : "\(failures.count) theme(s) couldn’t load. \(failures[0])"
        themeStatus.maximumNumberOfLines = 2
        themeStatus.toolTip = failures.joined(separator: "\n")
        NotificationCenter.default.post(name: .editorPreferencesChanged, object: nil)
    }

    @objc private func changePreferences(_ sender: NSControl) {
        if sender === lightPicker { EditorPreferences.lightTheme = lightPicker.selectedItem?.representedObject as? String ?? "Paper" }
        if sender === darkPicker { EditorPreferences.darkTheme = darkPicker.selectedItem?.representedObject as? String ?? "Midnight" }
        if sender === fontPicker { EditorPreferences.fontName = fontPicker.titleOfSelectedItem! }
        if sender === sizeField { EditorPreferences.fontSize = sizeField.doubleValue }
        if sender === heightField { EditorPreferences.lineHeight = heightField.doubleValue }
        if sender === wrapButton { EditorPreferences.wrapLines = wrapButton.state == .on }
        if sender === lineNumbersButton { EditorPreferences.showLineNumbers = lineNumbersButton.state == .on }
    }

    private func syncDisplayPreferences() {
        wrapButton.state = EditorPreferences.wrapLines ? .on : .off
        lineNumbersButton.state = EditorPreferences.showLineNumbers ? .on : .off
    }

    @objc private func makeDefault(_ sender: NSButton) {
        sender.isEnabled = false
        progress.startAnimation(nil)
        status.stringValue = "Updating remaining file types… macOS may ask you to confirm each change."
        Task { @MainActor in
            let result = await DefaultEditor.register()
            sender.isEnabled = true
            progress.stopAnimation(nil)
            if result.cancelled {
                status.stringValue = "Stopped. Updated \(result.updated) file types before cancellation."
            } else if result.failures.isEmpty {
                status.stringValue = result.updated == 0
                    ? "Fst is already the default editor for all supported file types."
                    : "Fst is now the default editor for all supported file types."
            } else {
                status.stringValue = "Fst is the default for \(result.updated + result.alreadyDefault) file types. \(result.failures.count) could not be changed."
                let alert = NSAlert()
                alert.messageText = "Some file types could not be changed"
                alert.informativeText = result.failures.prefix(5).joined(separator: "\n\n")
                if result.failures.count > 5 {
                    alert.informativeText += "\n\nAnd \(result.failures.count - 5) more file types."
                }
                alert.addButton(withTitle: "OK")
                if let window { alert.beginSheetModal(for: window, completionHandler: nil) }
            }
        }
    }
}
