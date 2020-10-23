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
import StatsKit
import ModuleKit

internal class Settings: NSView, Settings_v {
    private var updateIntervalValue: Int = 1
    
    private let title: String
    private let store: UnsafePointer<Store>
    private var button: NSPopUpButton?
    private let list: UnsafeMutablePointer<[Fan]>
    private var labelState: Bool = false
    
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    public init(_ title: String, store: UnsafePointer<Store>, list: UnsafeMutablePointer<[Fan]>) {
        self.title = title
        self.store = store
        self.list = list
        
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.wantsLayer = true
        self.canDrawConcurrently = true
        
        self.updateIntervalValue = store.pointee.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.labelState = store.pointee.bool(key: "\(self.title)_label", defaultValue: self.labelState)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(widget: widget_t) {
        guard !self.list.pointee.isEmpty else {
            return
        }
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let rowHeight: CGFloat = 30
        let settingsHeight: CGFloat = rowHeight*2 + Constants.Settings.margin
        let sensorsListHeight: CGFloat = (rowHeight+Constants.Settings.margin) * CGFloat(self.list.pointee.count) + ((rowHeight+Constants.Settings.margin))
        let height: CGFloat = settingsHeight + sensorsListHeight
        let x: CGFloat = height < 360 ? 0 : Constants.Settings.margin
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: self.frame.width - (Constants.Settings.margin*2) - x,
            height: height
        ))
        
        self.addSubview(SelectTitleRow(
            frame: NSRect(x: Constants.Settings.margin, y: height - rowHeight, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        self.addSubview(ToggleTitleRow(
            frame: NSRect(x: Constants.Settings.margin, y: height - rowHeight*2 - Constants.Settings.margin, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Label"),
            action: #selector(toggleLabelState),
            state: self.labelState
        ))
        
        let rowTitleView: NSView = NSView(frame: NSRect(x: 0, y: height - (rowHeight*3) - Constants.Settings.margin*2, width: view.frame.width, height: rowHeight))
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (rowHeight-19)/2, width: view.frame.width, height: 19), "Fans")
        rowTitle.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        rowTitle.textColor = .secondaryLabelColor
        rowTitle.alignment = .center
        rowTitleView.addSubview(rowTitle)
        view.addSubview(rowTitleView)
        
        var y: CGFloat = 0
        self.list.pointee.reversed().forEach { (f: Fan) in
            let row: NSView = ToggleTitleRow(
                frame: NSRect(x: 0, y: y, width: view.frame.width, height: rowHeight),
                title: f.name,
                action: #selector(self.handleSelection),
                state: f.state
            )
            row.subviews.filter{ $0 is NSControl }.forEach { (control: NSView) in
                control.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(f.id)")
            }
            view.addSubview(row)
            y += rowHeight + Constants.Settings.margin
        }
        
        self.addSubview(view)
        self.setFrameSize(NSSize(width: self.frame.width, height: height + (Constants.Settings.margin*1)))
    }
    
    @objc func handleSelection(_ sender: NSControl) {
        guard let id = sender.identifier else { return }
        
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.store.pointee.set(key: "fan_\(id.rawValue)", value:  state! == NSControl.StateValue.on)
        self.callback()
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            self.store.pointee.set(key: "\(self.title)_updateInterval", value: value)
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
        self.store.pointee.set(key: "\(self.title)_label", value: self.labelState)
        self.callback()
    }
}
