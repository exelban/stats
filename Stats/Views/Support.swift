//
//  Support.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2025
//  Using Swift 6.0
//  Running on macOS 15.1
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//  

import Cocoa
import Kit

internal class SupportWindow: NSWindow, NSWindowDelegate {
    private let viewController: SupportViewController = SupportViewController()
    
    init() {
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - self.viewController.view.frame.width,
                y: NSScreen.main!.frame.height - self.viewController.view.frame.height,
                width: self.viewController.view.frame.width,
                height: self.viewController.view.frame.height
            ),
            styleMask: [.closable, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        
        self.title = "Support Stats"
        self.titleVisibility = .hidden
        self.contentViewController = self.viewController
        self.titlebarAppearsTransparent = true
        self.positionCenter()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }
    
    private func positionCenter() {
        self.setFrameOrigin(NSPoint(
            x: (NSScreen.main!.frame.width - self.viewController.view.frame.width)/2,
            y: (NSScreen.main!.frame.height - self.viewController.view.frame.height)/1.75
        ))
    }
    
    internal func show() {
        self.setIsVisible(true)
        self.orderFrontRegardless()
    }
}

private class SupportViewController: NSViewController {
    private var support: SupportView
    
    public init() {
        self.support = SupportView(frame: NSRect(x: 0, y: 0, width: 460, height: 340))
        super.init(nibName: nil, bundle: nil)
        self.view = self.support
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class SupportView: NSStackView {
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        self.orientation = .vertical
        self.spacing = 0
        
        let sidebar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        
        self.addSubview(sidebar, positioned: .below, relativeTo: nil)
        
        let container: NSStackView = NSStackView()
        container.widthAnchor.constraint(equalToConstant: self.frame.width - 40).isActive = true
        container.orientation = .vertical
        
        let textField: NSTextField = TextView()
        textField.wantsLayer = false
        textField.alignment = .center
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.stringValue = localizedString("Support text")
        textField.isSelectable = false
        container.addArrangedSubview(NSView())
        container.addArrangedSubview(textField)
        container.addArrangedSubview(NSView())
        
        let support: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 160, height: 60))
        support.heightAnchor.constraint(equalToConstant: 80).isActive = true
        support.edgeInsets = NSEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
        support.spacing = 20
        support.orientation = .horizontal
        
        let github = SupportButtonView(name: "GitHub Sponsors", image: "github", action: {
            NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/exelban")!)
        })
        let paypal = SupportButtonView(name: "PayPal", image: "paypal", action: {
            NSWorkspace.shared.open(URL(string: "https://www.paypal.com/donate?hosted_button_id=3DS5JHDBATMTC")!)
        })
        let koFi = SupportButtonView(name: "Ko-fi", image: "ko-fi", action: {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/exelban")!)
        })
        let patreon = SupportButtonView(name: "Patreon", image: "patreon", action: {
            NSWorkspace.shared.open(URL(string: "https://patreon.com/exelban")!)
        })
        
        support.addArrangedSubview(github)
        support.addArrangedSubview(paypal)
        support.addArrangedSubview(koFi)
        support.addArrangedSubview(patreon)
        
        let footer = NSStackView()
        footer.heightAnchor.constraint(equalToConstant: 60).isActive = true
        footer.orientation = .horizontal
        let close = NSButton()
        close.heightAnchor.constraint(equalToConstant: 28).isActive = true
        close.bezelStyle = .regularSquare
        close.title = localizedString("Close")
        close.toolTip = localizedString("Close")
        close.action = #selector(self.close)
        close.target = self
        footer.addArrangedSubview(close)
        
        self.addArrangedSubview(container)
        self.addArrangedSubview(support)
        self.addArrangedSubview(footer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func close() {
        self.window?.close()
    }
}
