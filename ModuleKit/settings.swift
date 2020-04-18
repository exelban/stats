//
//  settings.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 13/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Settings_p: NSView {
    var toggleCallback: () -> () { get set }
}

open class Settings: NSView, Settings_p {
    public var toggleCallback: () -> () = {}
    
    private let headerHeight: CGFloat = 42
    private var widgetSelectorHeight: CGFloat = Constants.Widget.height + (Constants.Settings.margin*2)
    
    private var title: String
    
    init(title: String, enabled: Bool, activeWidget: widget_t?, widgets: UnsafePointer<[widget_t]>?) {
        self.title = title
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(hexString: "#e7e7e7").cgColor
        
        header(self.title, state: enabled)
        widgetSelector(widgets, activeWidget: activeWidget)
    }
    
    private func widgetSelector(_ list: UnsafePointer<[widget_t]>?, activeWidget: widget_t?) {
        if list == nil || list?.pointee.count == 0 {
            self.widgetSelectorHeight = 0
            return
        }
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: self.frame.height - headerHeight - widgetSelectorHeight - Constants.Settings.margin, width: self.frame.width - (Constants.Settings.margin*2), height: widgetSelectorHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        view.layer!.cornerRadius = 3
        
        self.appearance = NSAppearance(named: .aqua)
        var x: CGFloat = Constants.Settings.margin
        for i in 0...(list?.pointee.count ?? 1) - 1 {
            if let widgetType = list?.pointee[i] {
                if let widget = LoadWidget(widgetType, preview: true) {
                    widget.setTitle(self.title)
                    view.addSubview(WidgetPreview(
                        frame: NSRect(x: x, y: Constants.Settings.margin, width: widget.frame.width, height: widgetSelectorHeight - (Constants.Settings.margin*2)),
                        title: self.title,
                        widget: widget,
                        state: activeWidget == widgetType
                    ))
                    x = widget.frame.width + (Constants.Settings.margin*2)
                }
            }
        }
        
        self.addSubview(view)
    }
    
    private func header(_ title: String, state: Bool) {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - headerHeight, width: self.frame.width, height: headerHeight))
        view.wantsLayer = true
        
        let titleView = NSTextField(frame: NSRect(x: Constants.Settings.margin, y: (view.frame.height-20)/2, width: self.frame.width - 65, height: 20))
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .black
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
        titleView.alignment = .natural
        titleView.font = NSFont.systemFont(ofSize: 18, weight: .light)
        titleView.stringValue = title
        
        var toggle: NSControl = NSControl()
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch(frame: NSRect(x: self.frame.width-55, y: 0, width: 50, height: view.frame.height))
            switchButton.state = state ? .on : .off
            switchButton.action = #selector(self.toggleEnable)
            switchButton.target = self

            toggle = switchButton
        } else {
            let button: NSButton = NSButton(frame: NSRect(x: self.frame.width-55, y: 0, width: 30, height: view.frame.height))
            button.setButtonType(.switch)
            button.state = state ? .on : .off
            button.title = ""
            button.action = #selector(self.toggleEnable)
            button.isBordered = false
            button.isTransparent = true
            
            toggle = button
        }
        
        let line: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(hexString: "#d1d1d1").cgColor
        
        view.addSubview(titleView)
        view.addSubview(toggle)
        view.addSubview(line)
        
        self.addSubview(view)
    }
    
    @objc func toggleEnable(_ sender: Any) {
        self.toggleCallback()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class WidgetPreview: NSView {
    private let type: widget_t
    private var state: Bool
    private let title: String
    
    public init(frame: NSRect, title: String, widget: Widget_p, state: Bool) {
        self.type = widget.type
        self.state = state
        self.title = title
        super.init(frame: frame)
        
        NotificationCenter.default.addObserver(self, selector: #selector(maybeActivate), name: .switchWidget, object: nil)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.borderColor = self.state ? NSColor.systemBlue.cgColor : NSColor.tertiaryLabelColor.cgColor
        self.layer?.borderWidth = 1
        
        self.addSubview(widget)
        
        let rect = NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: ["menu": self.type])
        self.addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseEntered(with: NSEvent) {
        self.layer?.borderColor = NSColor.systemBlue.cgColor
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        self.layer?.borderColor = self.state ? NSColor.systemBlue.cgColor : NSColor.tertiaryLabelColor.cgColor
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with: NSEvent) {
        if !self.state {
            NotificationCenter.default.post(name: .switchWidget, object: nil, userInfo: ["module": self.title, "widget": self.type.rawValue])
        }
    }
    
    @objc private func maybeActivate(_ notification: Notification) {
        if let moduleName = notification.userInfo?["module"] as? String {
            if moduleName == self.title {
                if let widgetName = notification.userInfo?["widget"] as? String {
                    if widgetName == self.type.rawValue {
                        self.layer?.borderColor = NSColor.systemBlue.cgColor
                        self.state = true
                    } else {
                        self.layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
                        self.state = false
                    }
                }
            }
        }
    }
}
