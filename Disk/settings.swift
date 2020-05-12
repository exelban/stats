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
import StatsKit
import ModuleKit

public class Settings: NSView, Settings_v {
    public var selectedDiskHandler: (String) -> Void = {_ in }
    
    private let title: String
    private let store: UnsafePointer<Store>
    private var selectedDisk: String
    private var button: NSPopUpButton?
    
    public init(_ title: String, store: UnsafePointer<Store>) {
        self.title = title
        self.store = store
        self.selectedDisk = store.pointee.string(key: "\(self.title)_disk", defaultValue: "")
        super.init(frame: CGRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: 0, height: 0))
        self.wantsLayer = true
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(rect: NSRect, widget: widget_t) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addDiskSelector(rect: rect)
        
        self.setFrameSize(NSSize(width: rect.width - (Constants.Settings.margin*2), height: 30 + (Constants.Settings.margin*2)))
    }
    
    private func addDiskSelector(rect: NSRect) {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: rect.width, height: 30))
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (view.frame.height - 16)/2, width: view.frame.width - 52, height: 17), "Disk to show")
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .labelColor
        
        self.button = NSPopUpButton(frame: NSRect(x: view.frame.width - 164, y: 0, width: 140, height: 30))
        self.button!.target = self
        self.button?.action = #selector(self.handleSelection)
        
        view.addSubview(rowTitle)
        view.addSubview(self.button!)
        
        self.addSubview(view)
    }
    
    internal func setList(_ list: DiskList) {
        let disks = list.list.map{ $0.name }
        DispatchQueue.main.async(execute: {
            if disks != self.button?.itemTitles {
                self.button?.addItems(withTitles: disks)
                self.button?.selectItem(withTitle: self.selectedDisk)
            }
        })
    }

    @objc func handleSelection(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        self.selectedDisk = item.title
        self.store.pointee.set(key: "\(self.title)_disk", value: item.title)
        self.selectedDiskHandler(item.title)
    }
}
