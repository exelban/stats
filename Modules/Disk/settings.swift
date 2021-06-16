//
//  settings.swift
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 12/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSView, Settings_v {
    private var removableState: Bool = false
    private var updateIntervalValue: Int = 10
    
    public var selectedDiskHandler: (String) -> Void = {_ in }
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    private let title: String
    private var selectedDisk: String
    private var button: NSPopUpButton?
    private var intervalSelectView: NSView? = nil
    
    public init(_ title: String) {
        self.title = title
        self.selectedDisk = Store.shared.string(key: "\(self.title)_disk", defaultValue: "")
        self.removableState = Store.shared.bool(key: "\(self.title)_removable", defaultValue: self.removableState)
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.wantsLayer = true
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let rowHeight: CGFloat = 30
        let num: CGFloat = 3
        
        self.intervalSelectView = selectTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * 2,
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        )
            self.addSubview(self.intervalSelectView!)
        
        self.addDiskSelector()
        
        self.addSubview(toggleTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * 0,
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: localizedString("Show removable disks"),
            action: #selector(toggleRemovable),
            state: self.removableState
        ))
        
        self.setFrameSize(NSSize(width: self.frame.width, height: rowHeight*num + (Constants.Settings.margin*(num+1))))
    }
    
    private func addDiskSelector() {
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin*2 + 30,
            width: self.frame.width - Constants.Settings.margin*2,
            height: 30
        ))
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (view.frame.height - 16)/2, width: view.frame.width - 52, height: 17), localizedString("Disk to show"))
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        self.button = NSPopUpButton(frame: NSRect(x: view.frame.width - 140, y: -1, width: 140, height: 30))
        self.button!.target = self
        self.button?.action = #selector(self.handleSelection)
        
        view.addSubview(rowTitle)
        view.addSubview(self.button!)
        
        self.addSubview(view)
    }
    
    internal func setList(_ list: Disks) {
        let disks = list.map{ $0.mediaName }
        DispatchQueue.main.async(execute: {
            if self.button?.itemTitles.count != disks.count {
                self.button?.removeAllItems()
            }
            
            if disks != self.button?.itemTitles {
                self.button?.addItems(withTitles: disks)
                if self.selectedDisk != "" {
                    self.button?.selectItem(withTitle: self.selectedDisk)
                }
            }
        })
    }
    
    @objc private func handleSelection(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        self.selectedDisk = item.title
        Store.shared.set(key: "\(self.title)_disk", value: item.title)
        self.selectedDiskHandler(item.title)
    }
    
    @objc private func toggleRemovable(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.removableState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_removable", value: self.removableState)
        self.callback()
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.setUpdateInterval(value: value)
        }
    }
    
    public func setUpdateInterval(value: Int) {
        self.updateIntervalValue = value
        Store.shared.set(key: "\(self.title)_updateInterval", value: value)
        self.setInterval(value)
    }
}
