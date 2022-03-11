//
//  settings.swift
//  Bluetooth
//
//  Created by Serhiy Mytrovtsiy on 07/07/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    public var callback: (() -> Void) = {}
    
    private var list: [String: Bool] = [:]
    private let emptyView: EmptyView = EmptyView()
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
        
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(self.emptyView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func load(widgets: [widget_t]) {}
    
    internal func setList(_ list: [BLEDevice]) {
        if self.list.count != list.count && !self.list.isEmpty {
            self.subviews.filter({ $0 is NSStackView && ($0 as! NSStackView).identifier != NSUserInterfaceItemIdentifier(rawValue: "emptyView") }).forEach{ $0.removeFromSuperview() }
            self.list = [:]
        }
        
        if list.isEmpty && self.emptyView.isHidden {
            self.emptyView.isHidden = false
            return
        } else if !list.isEmpty && !self.emptyView.isHidden {
            self.emptyView.isHidden = true
        }
        
        list.forEach { (d: BLEDevice) in
            if self.list[d.id] == nil {
                let row: NSView = toggleSettingRow(
                    title: d.name,
                    action: #selector(self.handleSelection),
                    state: d.state
                )
                row.subviews.filter{ $0 is NSControl }.forEach { (control: NSView) in
                    control.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(d.uuid?.uuidString ?? d.address)")
                }
                self.list[d.id] = true
                self.addArrangedSubview(row)
            }
        }
    }
    
    @objc private func handleSelection(_ sender: NSControl) {
        guard let id = sender.identifier else { return }
        
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        Store.shared.set(key: "ble_\(id.rawValue)", value: state! == NSControl.StateValue.on)
        self.callback()
    }
}

internal class EmptyView: NSStackView {
    public init(height: CGFloat = 120, isHidden: Bool = false) {
        super.init(frame: NSRect())
        
        self.heightAnchor.constraint(equalToConstant: height).isActive = true
        
        self.translatesAutoresizingMaskIntoConstraints = true
        self.orientation = .vertical
        self.distribution = .fillEqually
        self.isHidden = isHidden
        self.identifier = NSUserInterfaceItemIdentifier(rawValue: "emptyView")
        
        let textView: NSTextView = NSTextView()
        textView.heightAnchor.constraint(equalToConstant: (height/2)+6).isActive = true
        textView.alignment = .center
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.string = localizedString("No Bluetooth devices are available")
        
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
