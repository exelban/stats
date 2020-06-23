//
//  Settings.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 18/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

internal class Settings: NSView, Settings_v {
    private var hyperthreadState: Bool = false
    
    private let title: String
    private let store: UnsafePointer<Store>?
    
    public var callback: (() -> Void) = {}
    
    public init(_ title: String, store: UnsafePointer<Store>?) {
        self.title = title
        self.store = store
        super.init(frame: CGRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: Constants.Settings.width - (Constants.Settings.margin*2), height: 0))
        self.wantsLayer = true
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.hyperthreadState = store!.pointee.bool(key: "\(self.title)_hyperhreading", defaultValue: self.hyperthreadState)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widget: widget_t) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let rowHeight: CGFloat = 29
        var height: CGFloat = 0
        
        if widget == .barChart {
            self.addSubview(ToggleTitleRow(
                frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * 0, width: self.frame.width - (Constants.Settings.margin*2), height: rowHeight),
                title: "Show hyper-threading cores",
                action: #selector(toggleMultithreading),
                state: self.hyperthreadState
            ))
            height += rowHeight
        }
        
        if height != 0 {
            height += (Constants.Settings.margin*2)
        }
        self.setFrameSize(NSSize(width: self.frame.width, height: height))
    }
    
    @objc func toggleMultithreading(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.hyperthreadState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_hyperhreading", value: self.hyperthreadState)
        self.callback()
    }
}
