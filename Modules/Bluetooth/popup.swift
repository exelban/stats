//
//  popup.swift
//  Bluetooth
//
//  Created by Serhiy Mytrovtsiy on 22/06/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private let emptyView: EmptyView = EmptyView(height: 30, isHidden: false, msg: localizedString("No Bluetooth devices are available"))
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 30))
        
        self.orientation = .vertical
        self.spacing = Constants.Popup.margins
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func batteryCallback(_ list: [BLEDevice]) {
        defer {
            if list.isEmpty && self.emptyView.superview == nil {
                self.addArrangedSubview(self.emptyView)
            } else if !list.isEmpty && self.emptyView.superview != nil {
                self.emptyView.removeFromSuperview()
            }
            
            let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing
            if h > 0 && self.frame.size.height != h {
                self.setFrameSize(NSSize(width: self.frame.width, height: h))
                self.sizeCallback?(self.frame.size)
            }
        }
        
        var views = self.subviews.filter{ $0 is BLEView }.map{ $0 as! BLEView }
        if list.count < views.count && !views.isEmpty {
            views.forEach{ $0.removeFromSuperview() }
            views = []
        }
        
        list.reversed().forEach { (ble: BLEDevice) in
            if let view = self.subviews.filter({ $0 is BLEView }).map({ $0 as! BLEView }).first(where: { $0.address == ble.address }) {
                view.update(ble.batteryLevel)
            } else {
                self.addArrangedSubview(BLEView(
                    width: self.frame.width,
                    address: ble.address,
                    name: ble.name,
                    batteryLevel: ble.batteryLevel
                ))
            }
        }
    }
}

internal class BLEView: NSStackView {
    public var address: String
    
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: self.bounds.width, height: self.bounds.height)
    }
    
    private var levels: [NSTextField] = []
    
    public init(width: CGFloat, address: String, name: String, batteryLevel: [KeyValue_t]) {
        self.address = address
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 30))
        
        self.orientation = .horizontal
        self.alignment = .centerY
        self.spacing = 0
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        let nameView: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 0, height: 16))
        nameView.font = NSFont.systemFont(ofSize: 13, weight: .light)
        nameView.stringValue = name
        nameView.toolTip = address
        
        self.addArrangedSubview(nameView)
        self.addArrangedSubview(NSView())
        
        batteryLevel.forEach { (pair: KeyValue_t) in
            self.addLevel(pair)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = isDarkMode ? NSColor(hexString: "#111111", alpha: 0.25).cgColor : NSColor(hexString: "#f5f5f5", alpha: 1).cgColor
    }
    
    public func update(_ batteryLevel: [KeyValue_t]) {
        self.levels.filter{ v in !batteryLevel.contains(where: { $0.key == v.identifier?.rawValue }) }.forEach { (v: NSView) in
            v.removeFromSuperview()
        }
        self.levels = self.levels.filter{ v in batteryLevel.contains(where: { $0.key == v.identifier?.rawValue }) }
        
        batteryLevel.forEach { (pair: KeyValue_t) in
            if let view = self.levels.first(where: { $0.identifier?.rawValue == pair.key }) {
                view.stringValue = "\(pair.value)%"
            } else {
                self.addLevel(pair)
            }
        }
    }
    
    private func addLevel(_ pair: KeyValue_t) {
        let valueView: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 0, height: 13))
        valueView.identifier = NSUserInterfaceItemIdentifier(rawValue: pair.key)
        valueView.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        valueView.stringValue = "\(pair.value)%"
        valueView.toolTip = pair.key
        self.addArrangedSubview(valueView)
        self.levels.append(valueView)
    }
}
