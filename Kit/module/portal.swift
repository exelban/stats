//
//  portal.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 17/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Portal_p: NSView {
    var name: String { get }
}

open class PortalWrapper: NSStackView, Portal_p {
    public var name: String
    
    private let header: PortalHeader
    
    public init(_ type: ModuleType, height: CGFloat = Constants.Popup.portalHeight) {
        self.name = type.rawValue
        self.header = PortalHeader(type.rawValue)
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: height))
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.cornerRadius = 3
        
        self.orientation = .vertical
        self.distribution = .fillEqually
        self.spacing = Constants.Popup.spacing*2
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Popup.spacing*2,
            left: Constants.Popup.spacing*2,
            bottom: Constants.Popup.spacing*2,
            right: Constants.Popup.spacing*2
        )
        self.addArrangedSubview(self.header)
        
        self.load()
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    open func load() {
        self.addArrangedSubview(NSView())
    }
}

public class PortalHeader: NSStackView {
    private let name: String
    
    public init(_ name: String) {
        self.name = name
        
        super.init(frame: NSRect.zero)
        self.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        let title = NSTextField()
        title.isEditable = false
        title.isSelectable = false
        title.isBezeled = false
        title.wantsLayer = true
        title.textColor = .textColor
        title.backgroundColor = .clear
        title.canDrawSubviewsIntoLayer = true
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        title.stringValue = name
        
        let settings = NSButton()
        settings.heightAnchor.constraint(equalToConstant: 18).isActive = true
        settings.bezelStyle = .regularSquare
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.imageScaling = .scaleProportionallyDown
        settings.image = Bundle(for: type(of: self)).image(forResource: "settings")!
        settings.contentTintColor = .lightGray
        settings.isBordered = false
        settings.action = #selector(self.openSettings)
        settings.target = self
        settings.toolTip = localizedString("Open module settings")
        settings.focusRingType = .none
        
        self.addArrangedSubview(title)
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(settings)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func openSettings(_ sender: Any) {
        self.window?.setIsVisible(false)
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.name])
    }
}
