//
//  State.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 18/09/2022.
//  Using Swift 5.0.
//  Running on macOS 12.6.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class StateWidget: WidgetWrapper {
    private var activeColorState: SColor = .secondGreen
    private var nonactiveColorState: SColor = .secondRed
    
    private var value: Bool = false
    
    private var colors: [SColor] = SColor.allColors
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? Bool {
                        self.value = value
                    }
                }
            }
        }
        
        super.init(.state, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: 8 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.activeColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_activeColor", defaultValue: self.activeColorState.key))
            self.nonactiveColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_nonactiveColor", defaultValue: self.nonactiveColorState.key))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let circle = NSBezierPath(ovalIn: CGRect(x: Constants.Widget.margin.x, y: (self.frame.height - 8)/2, width: 8, height: 8))
        let color = self.value ? self.activeColorState : self.nonactiveColorState
        (color.additional as? NSColor)?.set()
        circle.fill()
    }
    
    public func setValue(_ value: Bool) {
        guard self.value != value else { return }
        self.value = value
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Active state color"), component: selectView(
                action: #selector(self.toggleActiveColor),
                items: self.colors,
                selected: self.activeColorState.key
            )),
            PreferencesRow(localizedString("Nonactive state color"), component: selectView(
                action: #selector(self.toggleNonactiveColor),
                items: self.colors,
                selected: self.nonactiveColorState.key
            ))
        ]))
        
        return view
    }
    
    @objc private func toggleActiveColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = SColor.allCases.first(where: { $0.key == key }) {
            self.activeColorState = newColor
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_activeColor", value: key)
        self.display()
    }
    
    @objc private func toggleNonactiveColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = SColor.allCases.first(where: { $0.key == key }) {
            self.nonactiveColorState = newColor
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_nonactiveColor", value: key)
        self.display()
    }
}

public class PressureDotWidget: WidgetWrapper {
    private let visibleWidth: CGFloat = 8 + (2*Constants.Widget.margin.x)
    private var pressure: RAMPressure = .normal
    private var hideWhenNormalState: Bool = false

    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        if let config, preview,
           let previewConfig = config["Preview"] as? NSDictionary,
           let rawPressure = previewConfig["Pressure"] as? String,
           let pressure = RAMPressure(rawValue: rawPressure) {
            self.pressure = pressure
        }

        super.init(.pressureDot, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: self.visibleWidth,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))

        self.canDrawConcurrently = true

        if !preview {
            self.hideWhenNormalState = Store.shared.bool(
                key: "\(self.title)_\(self.type.rawValue)_hideWhenNormal",
                defaultValue: self.hideWhenNormalState
            )
        }

        let width = self.isDotVisible ? self.visibleWidth : 0
        self.shadowSize.width = width
        self.setFrameSize(NSSize(width: width, height: self.frame.size.height))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard self.isDotVisible else { return }

        let circle = NSBezierPath(ovalIn: CGRect(
            x: Constants.Widget.margin.x,
            y: (self.frame.height - 8) / 2,
            width: 8,
            height: 8
        ))
        self.pressure.pressureColor().set()
        circle.fill()
    }

    public override var occupiesMenuBarSpace: Bool {
        self.isDotVisible
    }

    public func setPressure(_ pressure: RAMPressure) {
        guard self.pressure != pressure else {
            self.updateVisibility()
            return
        }
        self.pressure = pressure
        self.updateVisibility()
    }

    public override func settings() -> NSView {
        let view = SettingsContainerView()

        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Hide when memory pressure is normal"), component: switchView(
                action: #selector(self.toggleHideWhenNormal),
                state: self.hideWhenNormalState
            ))
        ]))

        return view
    }

    private var isDotVisible: Bool {
        !(self.hideWhenNormalState && self.pressure == .normal)
    }

    private func updateVisibility() {
        let wasVisible = self.shadowSize.width > 0
        let isVisible = self.isDotVisible
        let width = isVisible ? self.visibleWidth : 0
        let widthChanged = self.shadowSize.width != width
        let visibilityChanged = wasVisible != isVisible

        self.shadowSize.width = width
        DispatchQueue.main.async {
            if widthChanged {
                self.setFrameSize(NSSize(width: width, height: self.frame.size.height))
            }
            if visibilityChanged {
                self.visibilityHandler?(isVisible)
            }
            if widthChanged {
                self.widthHandler?()
            }
            self.needsDisplay = true
        }
    }

    @objc private func toggleHideWhenNormal(_ sender: NSControl) {
        self.hideWhenNormalState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_hideWhenNormal", value: self.hideWhenNormalState)
        self.updateVisibility()
    }
}
