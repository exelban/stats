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
    var height: CGFloat { get }
}

open class PortalWrapper: NSStackView, Portal_p {
    public var name: String
    public var height: CGFloat
    
    private let header: PortalHeader
    public let body: NSStackView
    
    public init(_ type: ModuleType, height: CGFloat = 100) {
        self.name = type.stringValue
        self.height = 20 + Constants.Popup.spacing + height
        
        self.header = PortalHeader(type.stringValue)
        self.body = {
            let view = NSStackView()
            
            view.orientation = .horizontal
            view.distribution = .fillEqually
            
            view.spacing = Constants.Popup.spacing*2
            view.edgeInsets = NSEdgeInsets(
                top: Constants.Popup.spacing,
                left: Constants.Popup.spacing,
                bottom: Constants.Popup.spacing,
                right: Constants.Popup.spacing
            )
            
            return view
        }()
        
        super.init(frame: .zero)
        
        self.orientation = .vertical
        self.spacing = Constants.Popup.spacing
        
        self.addArrangedSubview(self.header)
        self.addArrangedSubview(self.body)
        
        self.load()
        
        if self.body.subviews.isEmpty {
            self.body.addArrangedSubview(NSView())
        }
        
        self.heightAnchor.constraint(equalToConstant: self.height).isActive = true
        self.body.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func load() {
        self.body.addArrangedSubview(NSView())
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
        title.alignment = .left
        title.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        title.stringValue = localizedString(name)
        
        let settings = NSButton()
        settings.heightAnchor.constraint(equalToConstant: 18).isActive = true
        settings.bezelStyle = .regularSquare
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.imageScaling = .scaleProportionallyDown
        settings.image = iconFromSymbol(name: "gearshape.fill", scale: .medium)
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
    
    @objc private func openSettings() {
        self.window?.setIsVisible(false)
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.name])
    }
}
