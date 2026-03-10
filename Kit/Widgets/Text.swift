//
//  Text.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 08/09/2024
//  Using Swift 5.0
//  Running on macOS 14.6
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//  

import Cocoa

public class TextWidget: WidgetWrapper {
    private var value: String = ""
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        super.init(.text, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: 30 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        if preview {
            self.value = "Text"
        }
        
        self.canDrawConcurrently = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var value: String = ""
        self.queue.sync {
            value = self.value
        }
        
        if value.isEmpty {
            self.setWidth(0)
            return
        }
        
        let valueSize: CGFloat = 12
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attributedString = NSAttributedString(string: value, attributes: stringAttributes)
        let size = attributedString.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let width = (size.width+Constants.Widget.margin.x*2).roundedUpToNearestTen()
        let origin: CGPoint = CGPoint(x: Constants.Widget.margin.x, y: ((Constants.Widget.height-valueSize-1)/2))
        let rect = CGRect(x: origin.x, y: origin.y, width: width - (Constants.Widget.margin.x*2), height: valueSize)
        attributedString.draw(with: rect)
        
        self.setWidth(width)
    }
    
    public func setValue(_ newValue: String) {
        guard self.value != newValue else { return }
        self.value = newValue
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    static public func parseText(_ raw: String) -> [KeyValue_t] {
        var pairs: [KeyValue_t] = []
        do {
            let regex = try NSRegularExpression(pattern: "(\\$[a-zA-Z0-9_]+)(?:\\.([a-zA-Z0-9_]+))?")
            let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: raw) {
                    let key = String(raw[keyRange])
                    let value: String?
                    if match.range(at: 2).location != NSNotFound, let valueRange = Range(match.range(at: 2), in: raw) {
                        value = String(raw[valueRange])
                    } else {
                        value = nil
                    }
                    pairs.append(KeyValue_t(key: key, value: value ?? ""))
                }
            }
        } catch {
            print("Error creating regex: \(error.localizedDescription)")
        }
        return pairs
    }
}

public class ProcessMemoryWidget: WidgetWrapper {
    private var showIconState: Bool = true
    private var showLabelState: Bool = true

    private var selection: ProcessMemorySelection? = nil
    private var value: TrackedProcessMemory? = nil

    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        super.init(.processMemory, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: 90,
            height: Constants.Widget.height - (2 * Constants.Widget.margin.y)
        ))

        if preview {
            let selection = ProcessMemorySelection(
                pid: 0,
                responsiblePid: 0,
                name: "Fabriqa",
                bundleIdentifier: nil,
                mode: .application
            )
            self.selection = selection
            self.value = TrackedProcessMemory(
                selection: selection,
                pid: nil,
                name: "Fabriqa",
                usage: 2.12 * Double(1024 * 1024 * 1024),
                bundleIdentifier: nil
            )
        } else {
            self.showIconState = Store.shared.bool(
                key: "\(self.title)_\(self.type.rawValue)_showIcon",
                defaultValue: self.showIconState
            )
            self.showLabelState = Store.shared.bool(
                key: "\(self.title)_\(self.type.rawValue)_showLabel",
                defaultValue: self.showLabelState
            )
            self.selection = ProcessMemorySelection.load(module: title)
        }

        self.canDrawConcurrently = true
        self.updateTooltip()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        var selection: ProcessMemorySelection? = nil
        var value: TrackedProcessMemory? = nil
        self.queue.sync {
            selection = self.selection
            value = self.value
        }

        let label = self.shortLabel(value?.displayName ?? selection?.displayName ?? localizedString("None"))
        let usageValue = value?.usage == nil
            ? "--"
            : Units(bytes: Int64(value?.usage ?? 0)).getReadableMemory(style: .memory)
        let icon = self.icon(selection: selection, value: value)
        let iconSize: CGFloat = 14
        let labelSize: CGFloat = 7
        let valueSize: CGFloat = self.showLabelState ? 11 : 12

        let style = NSMutableParagraphStyle()
        style.alignment = .left

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: labelSize, weight: .light),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style
        ]

        let labelWidth = NSAttributedString(string: label, attributes: labelAttributes)
            .boundingRect(with: CGSize(width: .greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).width
        let valueWidth = NSAttributedString(string: usageValue, attributes: valueAttributes)
            .boundingRect(with: CGSize(width: .greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).width

        var x = Constants.Widget.margin.x
        if self.showIconState {
            let iconRect = CGRect(
                x: x,
                y: ((Constants.Widget.height - iconSize) / 2) - 0.5,
                width: iconSize,
                height: iconSize
            )
            icon.draw(in: iconRect)
            x += iconSize + 4
        }

        let textWidth = max(labelWidth, valueWidth)
        if self.showLabelState {
            let labelRect = CGRect(
                x: x,
                y: 11.5,
                width: textWidth,
                height: labelSize + 1
            )
            NSAttributedString(string: label, attributes: labelAttributes).draw(with: labelRect)
        }

        let valueY: CGFloat = self.showLabelState ? 0.5 : ((Constants.Widget.height - valueSize) / 2) - 0.5
        let valueRect = CGRect(
            x: x,
            y: valueY,
            width: textWidth,
            height: valueSize + 1
        )
        NSAttributedString(string: usageValue, attributes: valueAttributes).draw(with: valueRect)

        let width = (x + textWidth + Constants.Widget.margin.x).roundedUpToNearestTen()
        self.setWidth(width)
    }

    public func setSelection(_ selection: ProcessMemorySelection?) {
        self.queue.sync {
            self.selection = selection
        }
        self.updateTooltip()
        DispatchQueue.main.async {
            self.display()
        }
    }

    public func setValue(_ value: TrackedProcessMemory?) {
        self.queue.sync {
            self.value = value
            if let selection = value?.selection {
                self.selection = selection
            }
        }
        self.updateTooltip()
        DispatchQueue.main.async {
            self.display()
        }
    }

    public override func settings() -> NSView {
        let view = SettingsContainerView()
        let selection = self.queue.sync { self.selection } ?? ProcessMemorySelection.load(module: self.title)
        let trackedName = selection?.displayName ?? localizedString("None")
        let trackingMode = selection?.mode.title ?? localizedString("None")

        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Selected item"), component: textView(trackedName, alignment: .right)),
            PreferencesRow(localizedString("Tracking"), component: textView(trackingMode, alignment: .right))
        ]))

        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Pictogram"), component: switchView(
                action: #selector(self.toggleShowIcon),
                state: self.showIconState
            )),
            PreferencesRow(localizedString("Label"), component: switchView(
                action: #selector(self.toggleShowLabel),
                state: self.showLabelState
            ))
        ]))

        return view
    }

    @objc private func toggleShowIcon(_ sender: NSControl) {
        self.showIconState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_showIcon", value: self.showIconState)
        self.display()
    }

    @objc private func toggleShowLabel(_ sender: NSControl) {
        self.showLabelState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_showLabel", value: self.showLabelState)
        self.display()
    }

    private func shortLabel(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 10 else { return trimmed }
        return "\(trimmed.prefix(9))…"
    }

    private func icon(selection: ProcessMemorySelection?, value: TrackedProcessMemory?) -> NSImage {
        if let pid = value?.pid,
           let app = NSRunningApplication(processIdentifier: pid_t(pid)),
           let icon = app.icon {
            return icon
        }
        if let bundleIdentifier = value?.bundleIdentifier ?? selection?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let icon = app.icon {
            return icon
        }
        if let pid = selection?.responsiblePid,
           let app = NSRunningApplication(processIdentifier: pid_t(pid)),
           let icon = app.icon {
            return icon
        }
        return Constants.defaultProcessIcon
    }

    private func updateTooltip() {
        let selection = self.queue.sync { self.selection }
        let trackedName = selection?.displayName ?? localizedString("None")
        let trackingMode = selection?.mode.title ?? localizedString("None")
        DispatchQueue.main.async {
            self.toolTip = "\(trackedName) (\(trackingMode))"
        }
    }
}
