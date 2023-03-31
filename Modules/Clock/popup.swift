//
//  popup.swift
//  Clock
//
//  Created by Serhiy Mytrovtsiy on 24/03/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.spacing = Constants.Popup.margins
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func callback(_ list: [Clock_t]) {
        defer {
            let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing
            if h > 0 && self.frame.size.height != h {
                self.setFrameSize(NSSize(width: self.frame.width, height: h))
                self.sizeCallback?(self.frame.size)
            }
        }
        
        var views = self.subviews.filter{ $0 is ClockView }.compactMap{ $0 as? ClockView }
        if list.count < views.count && !views.isEmpty {
            views.forEach{ $0.removeFromSuperview() }
            views = []
        }
        
        list.forEach { (c: Clock_t) in
            if let view = views.first(where: { $0.clock.id == c.id }) {
                view.update(c)
            } else {
                self.addArrangedSubview(ClockView(width: self.frame.width, clock: c))
            }
        }
    }
}

private class ClockView: NSStackView {
    public var clock: Clock_t
    
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: self.bounds.width, height: self.bounds.height)
    }
    
    private var ready: Bool = false
    
    private let clockView: ClockChart = ClockChart()
    private let nameField: NSTextField = TextView()
    private let timeField: NSTextField = TextView()
    
    init(width: CGFloat, clock: Clock_t) {
        self.clock = clock
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 44))
        
        self.orientation = .horizontal
        self.spacing = 5
        self.edgeInsets = NSEdgeInsets(
            top: 5,
            left: 5,
            bottom: 5,
            right: 5
        )
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.clockView.widthAnchor.constraint(equalToConstant: 34).isActive = true
        
        let container: NSStackView = NSStackView()
        container.orientation = .vertical
        container.spacing = 2
        container.distribution = .fillEqually
        container.alignment = .left
        
        self.nameField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        self.setTZ()
        self.nameField.cell?.truncatesLastVisibleLine = true
        
        self.timeField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        self.timeField.stringValue = clock.formatted()
        self.timeField.cell?.truncatesLastVisibleLine = true
        
        container.addArrangedSubview(self.nameField)
        container.addArrangedSubview(self.timeField)
        
        self.addArrangedSubview(self.clockView)
        self.addArrangedSubview(container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = isDarkMode ? NSColor(hexString: "#111111", alpha: 0.25).cgColor : NSColor(hexString: "#f5f5f5", alpha: 1).cgColor
    }
    
    private func setTZ() {
        self.nameField.stringValue = "\(self.clock.name)"
        if let tz = Clock.zones.first(where: { $0.key == self.clock.tz }) {
            self.nameField.stringValue += " (\(tz.value))"
        }
    }
    
    public func update(_ newClock: Clock_t) {
        if self.clock.tz != newClock.tz {
            self.clock = newClock
            self.setTZ()
        }
        
        if (self.window?.isVisible ?? false) || !self.ready {
            self.timeField.stringValue = newClock.formatted()
            if let value = newClock.value {
                self.clockView.setValue(value.convertToTimeZone(TimeZone(fromUTC: newClock.tz)))
            }
            self.ready = true
        }
    }
}

private class ClockChart: NSView {
    private var color: NSColor = Color.systemAccent.additional as! NSColor
    
    private let calendar = Calendar.current
    private var hour: Int!
    private var minute: Int!
    private var second: Int!
    
    private let hourLayer = CALayer()
    private let minuteLayer = CALayer()
    private let secondsLayer = CALayer()
    private let pinLayer = CAShapeLayer()
    
    override init(frame: CGRect = NSRect.zero) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard (self.hour != nil), (self.minute != nil), (self.second != nil) else { return }
        
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        context.setFillColor(self.color.cgColor)
        context.fillEllipse(in: dirtyRect)
        context.restoreGState()
        
        let anchor = CGPoint(x: 0.5, y: 0)
        let center = CGPoint(x: dirtyRect.size.width / 2, y: dirtyRect.size.height / 2)
        
        let hourAngle: CGFloat = CGFloat(Double(hour) * (360.0 / 12.0)) + CGFloat(Double(minute) * (1.0 / 60.0) * (360.0 / 12.0))
        let minuteAngle: CGFloat = CGFloat(minute) * CGFloat(360.0 / 60.0)
        let secondsAngle: CGFloat = CGFloat(self.second) * CGFloat(360.0 / 60.0)
        
        self.hourLayer.backgroundColor = NSColor.white.cgColor
        self.hourLayer.anchorPoint = anchor
        self.hourLayer.position = center
        self.hourLayer.bounds = CGRect(x: 0, y: 0, width: 3, height: dirtyRect.size.width / 2 - 7)
        self.hourLayer.transform = CATransform3DMakeRotation(-hourAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.hourLayer)
        
        self.minuteLayer.backgroundColor = NSColor.white.cgColor
        self.minuteLayer.anchorPoint = anchor
        self.minuteLayer.position = center
        self.minuteLayer.bounds = CGRect(x: 0, y: 0, width: 2, height: dirtyRect.size.width / 2 - 4)
        self.minuteLayer.transform = CATransform3DMakeRotation(-minuteAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.minuteLayer)
        
        self.secondsLayer.backgroundColor = NSColor.red.cgColor
        self.secondsLayer.anchorPoint = anchor
        self.secondsLayer.position = center
        self.secondsLayer.bounds = CGRect(x: 0, y: 0, width: 1, height: dirtyRect.size.width / 2 - 2)
        self.secondsLayer.transform = CATransform3DMakeRotation(-secondsAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.secondsLayer)
        
        self.pinLayer.fillColor = NSColor.white.cgColor
        self.pinLayer.anchorPoint = anchor
        self.pinLayer.path = CGMutablePath(roundedRect: CGRect(
            x: center.x - 3 / 2,
            y: center.y - 3 / 2,
            width: 3,
            height: 3
        ), cornerWidth: 4, cornerHeight: 4, transform: nil)
        self.layer?.addSublayer(self.pinLayer)
    }
    
    public func setValue(_ value: Date) {
        self.hour = self.calendar.component(.hour, from: value)
        self.minute = self.calendar.component(.minute, from: value)
        self.second = self.calendar.component(.second, from: value)
        
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
}
