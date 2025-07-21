//
//  portal.swift
//  Clock
//
//  Created by Serhiy Mytrovtsiy on 28/12/2023
//  Using Swift 5.0
//  Running on macOS 14.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import AppKit
import Kit

public class Portal: NSStackView, Portal_p {
    public var name: String
    
    private let container = ScrollableStackView()
    private var initialized: Bool = false
    private var list: [Clock_t] = []
    
    init(_ module: ModuleType, list: [Clock_t]) {
        self.name = module.stringValue
        
        super.init(frame: NSRect( x: 0, y: 0, width: Constants.Popup.width, height: Constants.Popup.portalHeight))
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.cornerRadius = 3
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = Constants.Popup.spacing*2
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Popup.spacing*2,
            left: Constants.Popup.spacing*2,
            bottom: Constants.Popup.spacing*2,
            right: Constants.Popup.spacing*2
        )
        
        self.container.stackView.spacing = 0
        self.container.widthAnchor.constraint(equalToConstant: Constants.Popup.width).isActive = true
        
        self.addArrangedSubview(PortalHeader(name))
        self.addArrangedSubview(self.container)
        
        self.callback(list)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    public func callback(_ list: [Clock_t]) {
        var sorted = list.sorted(by: { $0.popupIndex < $1.popupIndex })
        var views = self.container.stackView.subviews.filter{ $0 is ClockView }.compactMap{ $0 as? ClockView }
        
        sorted = sorted.filter({ $0.popupState })
        
        if sorted.count < views.count && !views.isEmpty {
            views.forEach{ $0.removeFromSuperview() }
            views = []
        }
        
        var width: CGFloat = self.frame.width - self.edgeInsets.left - self.edgeInsets.right
        if sorted.count > 2 {
            width -= self.container.scrollWidth ?? Constants.Popup.margins
        }
        
        if sorted.count != views.count {
            views.forEach { c in
                c.widthAnchor.constraint(equalToConstant: width).isActive = true
            }
        }
        
        sorted.forEach { (c: Clock_t) in
            if let view = views.first(where: { $0.clock.id == c.id }) {
                view.update(c)
            } else {
                self.container.stackView.addArrangedSubview(ClockView(width: width, clock: c))
            }
        }
        
        self.list = sorted
    }
}

private func setFullWidth(_ view: NSView, width: CGFloat) {
    if let widthConstraint = view.constraints.first(where: { $0.firstAttribute == .width }) {
        widthConstraint.constant = width
    } else {
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
    }
}
