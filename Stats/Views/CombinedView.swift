//
//  CombinedView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 09/01/2023
//  Using Swift 5.0
//  Running on macOS 13.1
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class CombinedView {
    private var menuBarItem: NSStatusItem? = nil
    private var view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: Constants.Widget.height))
    private var popup: PopupWindow? = nil
    
    private var status: Bool {
        Store.shared.bool(key: "CombinedModules", defaultValue: false)
    }
    private var spacing: CGFloat {
        CGFloat(Int(Store.shared.string(key: "CombinedModules_spacing", defaultValue: "")) ?? 0)
    }
    
    init() {
        modules.forEach { (m: Module) in
            m.menuBar.callback = { [weak self] in
                if let s = self?.status, s {
                    DispatchQueue.main.async(execute: {
                        self?.recalculate()
                    })
                }
            }
        }
        
        self.popup = PopupWindow(title: "Combined modules", view: Popup()) { _ in }
        
        if self.status {
            self.enable()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForOneView), name: .toggleOneView, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForModuleRearrrange), name: .moduleRearrange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleOneView, object: nil)
    }
    
    public func enable() {
        self.menuBarItem = NSStatusBar.system.statusItem(withLength: 0)
        self.menuBarItem?.autosaveName = "CombinedModules"
        self.menuBarItem?.button?.addSubview(self.view)
        
        self.menuBarItem?.button?.target = self
        self.menuBarItem?.button?.action = #selector(self.togglePopup)
        self.menuBarItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        
        DispatchQueue.main.async(execute: {
            self.recalculate()
        })
    }
    
    public func disable() {
        if let item = self.menuBarItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        self.menuBarItem = nil
    }
    
    private func recalculate() {
        self.view.subviews.forEach({ $0.removeFromSuperview() })
        
        var w: CGFloat = 0
        var i: Int = 0
        modules.filter({ $0.enabled }).sorted(by: { $0.combinedPosition < $1.combinedPosition }).forEach { (m: Module) in
            self.view.addSubview(m.menuBar.view)
            self.view.subviews[i].setFrameOrigin(NSPoint(x: w, y: 0))
            w += m.menuBar.view.frame.width + self.spacing
            i += 1
        }
        self.view.setFrameSize(NSSize(width: w, height: self.view.frame.height))
        self.menuBarItem?.length = w
    }
    
    // call when popup appear/disappear
    private func visibilityCallback(_ state: Bool) {}
    
    @objc private func togglePopup(_ sender: Any) {
        guard let popup = self.popup, let item = self.menuBarItem, let window = item.button?.window else { return }
        let openedWindows = NSApplication.shared.windows.filter{ $0 is NSPanel }
        openedWindows.forEach{ $0.setIsVisible(false) }
        
        if(popup.locked){
            popup.orderFront(self)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        else if popup.occlusionState.rawValue == 8192 {
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            popup.contentView?.invalidateIntrinsicContentSize()
            
            let windowCenter = popup.contentView!.intrinsicContentSize.width / 2
            var x = window.frame.origin.x - windowCenter + window.frame.width/2
            let y = window.frame.origin.y - popup.contentView!.intrinsicContentSize.height - 3
            
            let maxWidth = NSScreen.screens.map{ $0.frame.width }.reduce(0, +)
            if x + popup.contentView!.intrinsicContentSize.width > maxWidth {
                x = maxWidth - popup.contentView!.intrinsicContentSize.width - 3
            }
            
            popup.setFrameOrigin(NSPoint(x: x, y: y))
            popup.setIsVisible(true)
        } else {
            popup.setIsVisible(false)
        }
    }
    
    @objc private func listenForOneView(_ notification: Notification) {
        guard notification.userInfo?["module"] == nil else { return }
        
        if self.status {
            self.enable()
        } else {
            self.disable()
        }
    }
    
    @objc private func listenForModuleRearrrange() {
        self.recalculate()
    }
}

private class Popup: NSStackView, Popup_p, NSGestureRecognizerDelegate {
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .width
        self.spacing = Constants.Popup.spacing
        
        self.reinit()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reinit), name: .toggleModule, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleOneView, object: nil)
    }
    
    public func settings() -> NSView? { return nil }
    public func appear() {}
    public func disappear() {}
    
    @objc private func reinit() {
        self.subviews.forEach({ $0.removeFromSuperview() })
        
        let availableModules = modules.filter({ $0.enabled && $0.portal != nil })
        let pairs = stride(from: 0, to: availableModules.endIndex, by: 2).map {
            (availableModules[$0], $0 < availableModules.index(before: availableModules.endIndex) ? availableModules[$0.advanced(by: 1)] : nil)
        }
        pairs.forEach { (m1: Module, m2: Module?) in
            let row = NSStackView()
            row.orientation = .horizontal
            row.distribution = .fillEqually
            row.spacing = Constants.Popup.spacing
            
            if let p = m1.portal {
                addPortal(p:p, row:row)
            }
            if let p = m2?.portal {
                addPortal(p:p, row:row)
            }
            
            self.addArrangedSubview(row)
        }
        
        let h = CGFloat(pairs.count) * Constants.Popup.portalHeight + (CGFloat(pairs.count)*Constants.Popup.spacing)
        self.setFrameSize(NSSize(width: self.frame.width, height: h))
        self.sizeCallback?(self.frame.size)
    }
    
    func addPortal(p:Portal_p, row:NSStackView){
        let clickRecognizer = portalClick(target: self, action: #selector(self.togglePopup))
        clickRecognizer.name = p.name
        clickRecognizer.delegate = self
        p.addGestureRecognizer(clickRecognizer)
        row.addArrangedSubview(p)
    }
    
    @objc private func togglePopup(_ sender: Any) {
        if let window = self.window {
            let portalClick = sender as! portalClick
            let location = CGPoint(x:window.frame.origin.x,y:window.frame.maxY + 3)
            NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
                "module": portalClick.name,
                "origin": location,
                "center": window.frame.width/2
            ])
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        //prevents the click from being recognized if the setup button is pressed
        let thePoint = gestureRecognizer.location(in: self.superview)
        if let theView = self.hitTest(thePoint) {
            return !(theView is NSButton)
        }
        else {
            return true
        }
    }
}

class portalClick: NSClickGestureRecognizer {
    var name: String = ""

}
