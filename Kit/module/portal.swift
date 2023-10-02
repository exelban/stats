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
