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
    public var selectedBatteryHandler: (String) -> Void = {_ in }
    
    private let title: String
    private var selectedBattery: String
    private var button: NSPopUpButton?
    
    public init(_ title: String) {
        self.title = title
        self.selectedBattery = Store.shared.string(key: "\(self.title)_battery", defaultValue: "")
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addArrangedSubview(self.deviceSelector())
        
        let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing + self.edgeInsets.top + self.edgeInsets.bottom
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.bounds.width, height: h))
        }
    }
    
    private func deviceSelector() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width - Constants.Settings.margin*2, height: Constants.Settings.row))
        
        let rowTitle: NSTextField = LabelField(
            frame: NSRect(x: 0, y: (view.frame.height - 16)/2, width: view.frame.width - 52, height: 17),
            localizedString("Battery to show")
        )
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        self.button = NSPopUpButton(frame: NSRect(x: view.frame.width - 140, y: -1, width: 140, height: 30))
        self.button!.target = self
        self.button?.action = #selector(self.handleSelection)
        
        view.addSubview(rowTitle)
        view.addSubview(self.button!)
        
        return view
    }
    
    internal func setList(_ list: [BLEDevice]) {
        var batteries: [String] = []
        list.forEach { (d: BLEDevice) in
            if d.batteryLevel.count == 1 {
                batteries.append(d.name)
            } else {
                d.batteryLevel.forEach { (pair: KeyValue_t) in
                    batteries.append("\(d.name)@\(pair.key)")
                }
            }
        }
        
        DispatchQueue.main.async(execute: {
            if self.button?.itemTitles.count != batteries.count {
                self.button?.removeAllItems()
            }
            
            if batteries != self.button?.itemTitles {
                self.button?.addItems(withTitles: batteries.map{ $0.replacingOccurrences(of: "@", with: " - ")})
                if self.selectedBattery != "" {
                    self.button?.selectItem(withTitle: self.selectedBattery.replacingOccurrences(of: "@", with: " - "))
                }
            }
        })
    }
    
    @objc private func handleSelection(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        self.selectedBattery = item.title.replacingOccurrences(of: " - ", with: "@")
        Store.shared.set(key: "\(self.title)_battery", value: self.selectedBattery)
        self.selectedBatteryHandler(self.selectedBattery)
    }
}
