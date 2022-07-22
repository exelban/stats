//
//  Setup.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 21/07/2022.
//  Using Swift 5.0.
//  Running on macOS 12.4.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal protocol setup_p: NSView {
    func reset()
}

private let setupSize: CGSize = CGSize(width: 600, height: 400)

internal class SetupWindow: NSWindow, NSWindowDelegate {
    private let view: SetupContainer = SetupContainer()
    private let vc: NSViewController = NSViewController(nibName: nil, bundle: nil)
    
    public var finishHandler: () -> Void = {}
    
    init() {
        self.vc.view = self.view
        
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - self.view.frame.width,
                y: NSScreen.main!.frame.height - self.view.frame.height,
                width: self.view.frame.width,
                height: self.view.frame.height
            ),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = self.vc
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.titlebarAppearsTransparent = true
        self.delegate = self
        self.title = localizedString("Stats Setup")
        
        self.center()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }
    
    public func show() {
        self.setIsVisible(true)
    }
    
    public func hide() {
        self.close()
        self.finishHandler()
    }
}

private class SetupContainer: NSStackView {
    private let pages: [setup_p] = [SetupView_1()]
    
    private var main: NSView = NSView()
    private var prevBtn: NSButton = NSButton()
    private var nextBtn: NSButton = NSButton()
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height))
        self.orientation = .vertical
        self.spacing = 0
        
        self.addArrangedSubview(self.main)
        self.addArrangedSubview(self.footerView())
        
        self.setView(i: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.tertiaryLabelColor.set()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: 59))
        line.line(to: NSPoint(x: self.frame.width, y: 59))
        line.lineWidth = 0.25
        line.stroke()
    }
    
    private func footerView() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        
        let prev = NSButton()
        prev.bezelStyle = .regularSquare
        prev.isEnabled = false
        prev.title = localizedString("Previous")
        prev.toolTip = localizedString("Previous page")
        prev.action = #selector(self.prev)
        prev.target = self
        self.prevBtn = prev
        
        let next = NSButton()
        next.bezelStyle = .regularSquare
        next.title = localizedString("Next")
        next.toolTip = localizedString("Next page")
        next.action = #selector(self.next)
        next.target = self
        self.nextBtn = next
        
        container.addArrangedSubview(prev)
        container.addArrangedSubview(next)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),
            prev.heightAnchor.constraint(equalToConstant: 28),
            next.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return container
    }
    
    @objc private func prev() {
        if let current = self.main.subviews.first, let idx = self.pages.firstIndex(where: { $0 == current }) {
            self.setView(i: idx-1)
        }
    }
    
    @objc private func next() {
        if let current = self.main.subviews.first, let idx = self.pages.firstIndex(where: { $0 == current }) {
            if idx+1 >= self.pages.count, let window = self.window as? SetupWindow {
                window.hide()
                return
            }
            self.setView(i: idx+1)
        }
    }
    
    private func setView(i: Int) {
        guard self.pages.indices.contains(i) else { return }
        
        if i == 0 {
            self.prevBtn.isEnabled = false
            self.nextBtn.isEnabled = true
        } else if i == self.pages.count-1 {
            self.nextBtn.title = localizedString("Finish")
            self.nextBtn.toolTip = localizedString("Finish setup")
        } else {
            self.prevBtn.isEnabled = true
            self.nextBtn.isEnabled = true
            self.nextBtn.title = localizedString("Next")
            self.nextBtn.toolTip = localizedString("Next page")
        }
        
        let view = self.pages[i]
        view.reset()
        
        self.main.subviews.forEach({ $0.removeFromSuperview() })
        self.main.addSubview(view)
    }
}

private class SetupView_1: NSStackView, setup_p {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height - 60))
        
        let container: NSGridView = NSGridView()
        container.heightAnchor.constraint(equalToConstant: 220).isActive = true
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let icon: NSImageView = NSImageView(image: NSImage(named: NSImage.Name("AppIcon"))!)
        icon.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        let name: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 22))
        name.alignment = .center
        name.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        name.stringValue = localizedString("Welcome to Stats")
        name.toolTip = localizedString("Welcome to Stats")
        name.isSelectable = false
        
        let message: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 16))
        message.alignment = .center
        message.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        message.stringValue = localizedString("welcome_message")
        message.toolTip = localizedString("welcome_message")
        message.isSelectable = false
        
        container.addRow(with: [icon])
        container.addRow(with: [name])
        container.addRow(with: [message])
        
        container.row(at: 1).height = 36
        
        self.addArrangedSubview(container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func reset() {}
}
