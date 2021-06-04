//
//  settings.swift
//  Fans
//
//  Created by Serhiy Mytrovtsiy on 20/10/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private var updateIntervalValue: Int = 1
    
    private let title: String
    private var button: NSPopUpButton?
    private let list: UnsafeMutablePointer<[Fan]>
    private var labelState: Bool = false
    
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    public init(_ title: String, list: UnsafeMutablePointer<[Fan]>) {
        self.title = title
        self.list = list
        
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.wantsLayer = true
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
        
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.labelState = Store.shared.bool(key: "\(self.title)_label", defaultValue: self.labelState)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(widgets: [widget_t]) {
        guard !self.list.pointee.isEmpty else {
            return
        }
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addArrangedSubview(selectTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: 0,
                width: self.frame.width - (Constants.Settings.margin*2),
                height: Constants.Settings.row
            ),
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        self.addArrangedSubview(toggleTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: 0,
                width: self.frame.width - (Constants.Settings.margin*2),
                height: Constants.Settings.row
            ),
            title: localizedString("Label"),
            action: #selector(toggleLabelState),
            state: self.labelState
        ))
        
        let view: NSStackView = NSStackView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: self.frame.width - (Constants.Settings.margin*2),
            height: 0
        ))
        view.orientation = .vertical
        view.distribution = .gravityAreas
        view.spacing = Constants.Settings.margin
        
        let title: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 19), localizedString("Fans"))
        title.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        title.textColor = .secondaryLabelColor
        title.alignment = .center
        title.heightAnchor.constraint(equalToConstant: title.bounds.height).isActive = true
        view.addArrangedSubview(title)
        
        self.list.pointee.reversed().forEach { (f: Fan) in
            let row: NSView = toggleTitleRow(
                frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Settings.row),
                title: f.name,
                action: #selector(self.handleSelection),
                state: f.state
            )
            row.subviews.filter{ $0 is NSControl }.forEach { (control: NSView) in
                control.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(f.id)")
            }
            view.addArrangedSubview(row)
        }
        
        let listHeight = view.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing
        view.setFrameSize(NSSize(width: view.frame.width, height: listHeight))
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: listHeight),
            view.widthAnchor.constraint(equalToConstant: view.bounds.width)
        ])
        
        self.addArrangedSubview(view)
        
        let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing + self.edgeInsets.top + self.edgeInsets.bottom
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
        }
    }
    
    @objc func handleSelection(_ sender: NSControl) {
        guard let id = sender.identifier else { return }
        
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        Store.shared.set(key: "fan_\(id.rawValue)", value: state! == NSControl.StateValue.on)
        self.callback()
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            Store.shared.set(key: "\(self.title)_updateInterval", value: value)
            self.setInterval(value)
        }
    }
    
    @objc func toggleLabelState(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.labelState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_label", value: self.labelState)
        self.callback()
    }
}
