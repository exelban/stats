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
    
    private var initialized: Bool = false
    
    private var oneContainer: NSGridView = NSGridView()
    private var multiplyContainer: ScrollableStackView = ScrollableStackView(orientation: .horizontal)
    
    init(_ module: ModuleType, list: [Clock_t]) {
        self.name = module.rawValue
        
        super.init(frame: NSRect.zero)
        
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
        self.addArrangedSubview(PortalHeader(name))
        
        self.oneContainer.rowSpacing = 0
        self.oneContainer.yPlacement = .center
        self.oneContainer.xPlacement = .center
        
        self.addArrangedSubview(self.oneContainer)
        self.addArrangedSubview(self.multiplyContainer)
        
        self.callback(list)
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    public func callback(_ list: [Clock_t]) {
        let list = list.filter({ $0.popupState })
        
        if (self.window?.isVisible ?? false) || !self.initialized {
            if list.count == 1, let c = list.first {
                self.loadOne(c)
            } else {
                self.loadMultiply(list)
            }
            self.initialized = true
        }
    }
    
    private func loadOne(_ clock: Clock_t) {
        self.addArrangedSubview(self.oneContainer)
        self.multiplyContainer.removeFromSuperview()
        
        let views = self.oneContainer.subviews.compactMap{ $0 as? ClockChart }
        if let view = views.first(where: { $0.identifier?.rawValue == clock.id }) {
            if let value = clock.value {
                view.setValue(value.convertToTimeZone(TimeZone(fromUTC: clock.tz)))
            }
        } else {
            self.oneContainer.addRow(with: [self.clockView(clock)])
        }
    }
    
    private func loadMultiply(_ list: [Clock_t]) {
        self.addArrangedSubview(self.multiplyContainer)
        self.oneContainer.removeFromSuperview()
        
        let sorted = list.sorted(by: { $0.popupIndex < $1.popupIndex })
        var views = self.multiplyContainer.stackView.subviews.compactMap{ $0 as? ClockChart }
        
        if sorted.count < views.count && !views.isEmpty {
            views.forEach{ $0.removeFromSuperview() }
            views = []
        }
        
        sorted.forEach { (c: Clock_t) in
            if let view = views.first(where: { $0.identifier?.rawValue == c.id }) {
                if let value = c.value {
                    view.setValue(value.convertToTimeZone(TimeZone(fromUTC: c.tz)))
                }
            } else {
                self.multiplyContainer.stackView.addArrangedSubview(clockView(c))
            }
        }
    }
    
    private func clockView(_ clock: Clock_t) -> ClockChart {
        let view = ClockChart(frame: NSRect(x: 0, y: 0, width: 57, height: 57))
        view.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: view.frame.height).isActive = true
        view.identifier = NSUserInterfaceItemIdentifier(clock.id)
        
        if let value = clock.value {
            view.setValue(value.convertToTimeZone(TimeZone(fromUTC: clock.tz)))
        }
        
        return view
    }
}
