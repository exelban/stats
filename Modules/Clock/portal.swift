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

public class Portal: PortalWrapper {
    private let container = ClockListView()
    private var list: [Clock_t] = []
    
    public override func load() {
        self.container.stackView.spacing = 0
        self.container.wantsLayer = true
        self.container.layer?.cornerRadius = Constants.Popup.radius
        self.body.addArrangedSubview(self.container)
    }
    
    public func callback(_ list: [Clock_t]) {
        var sorted = list.sorted(by: { $0.popupIndex < $1.popupIndex })
        var views = self.container.stackView.subviews.filter{ $0 is ClockView }.compactMap{ $0 as? ClockView }
        
        sorted = sorted.filter({ $0.popupState })
        
        if sorted.count != views.count && !views.isEmpty {
            self.container.stackView.subviews.forEach{ $0.removeFromSuperview() }
            views = []
        }
        
        let width: CGFloat = Constants.Popup.width - (Constants.Popup.spacing*2)
        
        sorted.forEach { (c: Clock_t) in
            if let view = views.first(where: { $0.clock.id == c.id }) {
                view.update(c)
            } else {
                if !self.container.stackView.arrangedSubviews.isEmpty {
                    let separator = NSBox()
                    separator.boxType = .separator
                    self.container.stackView.addArrangedSubview(separator)
                    separator.widthAnchor.constraint(equalTo: self.container.stackView.widthAnchor).isActive = true
                }
                let view = ClockView(width: width, clock: c, background: false, nameSize: 10, timeSize: 12)
                self.container.stackView.addArrangedSubview(view)
                view.widthAnchor.constraint(equalTo: self.container.stackView.widthAnchor).isActive = true
            }
        }
        
        self.list = sorted
    }
}

private class ClockListView: ScrollableStackView {
    override var wantsUpdateLayer: Bool { true }
    
    override func updateLayer() {
        self.layer?.backgroundColor = (isDarkMode ? NSColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 0.25) : NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)).cgColor
    }
}
