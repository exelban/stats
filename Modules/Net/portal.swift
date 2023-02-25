//
//  portal.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 18/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Portal: NSStackView, Portal_p {
    public var name: String
    
    private var initialized: Bool = false
    
    private var uploadView: NSView? = nil
    private var uploadValueField: NSTextField? = nil
    private var uploadUnitField: NSTextField? = nil
    private var uploadColorView: ColorView? = nil
    
    private var downloadView: NSView? = nil
    private var downloadValueField: NSTextField? = nil
    private var downloadUnitField: NSTextField? = nil
    private var downloadColorView: ColorView? = nil
    
    private var base: DataSizeBase {
        get {
            DataSizeBase(rawValue: Store.shared.string(key: "\(self.name)_base", defaultValue: "byte")) ?? .byte
        }
    }
    
    private var downloadColorState: Color = .secondBlue
    private var downloadColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.downloadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var uploadColorState: Color = .secondRed
    private var uploadColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.uploadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    
    init(_ name: String) {
        self.name = name
        
        super.init(frame: NSRect.zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.cornerRadius = 3
        
        self.orientation = .horizontal
        self.distribution = .fillEqually
        self.spacing = 0
        self.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Popup.margins,
            bottom: Constants.Popup.margins,
            right: 0
        )
        
        let container = NSStackView()
        container.widthAnchor.constraint(equalToConstant: (Constants.Popup.width/2) - (Constants.Popup.margins*2)).isActive = true
        container.spacing = Constants.Popup.spacing
        container.orientation = .vertical
        container.distribution = .fillEqually
        container.spacing = 0
        
        let (uView, uField, uUnit, uColor) = self.IOView(operation: localizedString("Uploading"), color: self.uploadColor)
        let (dView, dField, dUnit, dColor) = self.IOView(operation: localizedString("Downloading"), color: self.downloadColor)
        
        self.uploadValueField = uField
        self.uploadUnitField = uUnit
        self.uploadColorView = uColor
        
        self.downloadValueField = dField
        self.downloadUnitField = dUnit
        self.downloadColorView = dColor
        
        container.addArrangedSubview(uView)
        container.addArrangedSubview(dView)
        
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(container)
        self.addArrangedSubview(NSView())
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    private func IOView(operation: String, color: NSColor) -> (NSView, NSTextField, NSTextField, ColorView) {
        let box = NSStackView()
        box.orientation = .vertical
        box.spacing = Constants.Popup.spacing
        box.translatesAutoresizingMaskIntoConstraints = false
        
        let value = NSStackView()
        value.orientation = .horizontal
        value.spacing = 0
        value.alignment = .bottom
        
        let valueField = LabelField("0")
        valueField.font = NSFont.systemFont(ofSize: 24, weight: .light)
        valueField.textColor = .textColor
        valueField.alignment = .right
        
        let unitField = LabelField("KB/s")
        unitField.heightAnchor.constraint(equalToConstant: 18).isActive = true
        unitField.font = NSFont.systemFont(ofSize: 13, weight: .light)
        unitField.textColor = .labelColor
        unitField.alignment = .left
        
        value.addArrangedSubview(valueField)
        value.addArrangedSubview(unitField)
        
        let title = NSStackView()
        title.orientation = .horizontal
        title.spacing = 0
        title.alignment = .centerY
        
        let colorBlock: ColorView = ColorView(color: color, radius: 3)
        colorBlock.widthAnchor.constraint(equalToConstant: 10).isActive = true
        colorBlock.heightAnchor.constraint(equalToConstant: 10).isActive = true
        
        let titleField = LabelField(operation)
        titleField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        titleField.alignment = .center
        
        title.addArrangedSubview(colorBlock)
        title.addArrangedSubview(titleField)
        
        box.addArrangedSubview(value)
        box.addArrangedSubview(title)
        
        return (box, valueField, unitField, colorBlock)
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                let upload = Units(bytes: value.bandwidth.upload).getReadableTuple(base: self.base)
                let download = Units(bytes: value.bandwidth.download).getReadableTuple(base: self.base)
                
                self.uploadValueField?.stringValue = "\(upload.0)"
                self.uploadUnitField?.stringValue = upload.1
                
                self.downloadValueField?.stringValue = "\(download.0)"
                self.downloadUnitField?.stringValue = download.1
                
                self.uploadColorView?.setState(value.bandwidth.upload != 0)
                self.downloadColorView?.setState(value.bandwidth.download != 0)
                
                self.initialized = true
            }
        })
    }
}
