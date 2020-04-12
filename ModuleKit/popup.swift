//
//  popup.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 11/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class PopupWindow: NSPanel {
    let viewController: PopupViewController = PopupViewController()
    
    init(title: String) {
        self.viewController.setup(title: title)
        
        super.init(
            contentRect: NSMakeRect(0, 0, self.viewController.view.frame.width, self.viewController.view.frame.height),
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = viewController
        self.backingType = .buffered
        self.isFloatingPanel = true
        self.styleMask = .borderless
        self.animationBehavior = .default
        self.collectionBehavior = .transient
        self.backgroundColor = .clear
        self.setIsVisible(false)
    }
}

class PopupViewController: NSViewController {
    private var popup: PopupView
    
    let width: CGFloat = 300
    let height: CGFloat = 400
    
    public init() {
        self.popup = PopupView(frame: NSRect(x: 0, y: 0, width: self.width, height: self.height))
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = self.popup
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public func setup(title: String) {
        self.title = title
        self.popup.headerView?.titleView?.stringValue = title
    }
}

class PopupView: NSView {
    public var headerView: HeaderView? = nil
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        self.layer!.cornerRadius = 3
        self.layer!.backgroundColor = self.isDarkMode ? NSColor.windowBackgroundColor.cgColor : NSColor.white.cgColor
        
        let headerHeight: CGFloat = 42
        self.headerView = HeaderView(frame: NSRect(x: 0, y: frame.height - headerHeight, width: frame.width, height: headerHeight))
        
        self.addSubview(self.headerView!)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer!.backgroundColor = self.isDarkMode ? NSColor.windowBackgroundColor.cgColor : NSColor.white.cgColor
    }
}

class HeaderView: NSView {
    public var titleView: NSTextField? = nil
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        let titleView = NSTextField(frame: NSMakeRect(frame.width/4, (frame.height - 18)/2, frame.width/2, 18))
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .labelColor
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
        titleView.alignment = .center
        titleView.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleView.stringValue = ""
        
        self.titleView = titleView
        self.addSubview(titleView)
        
        let button = NSButton()
        button.frame = CGRect(x: frame.width - 32, y: 12, width: 30, height: 30)
        button.bezelStyle = .regularSquare
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageScaling = .scaleAxesIndependently
        button.image = Bundle(for: type(of: self)).image(forResource: "settings")!
        button.contentTintColor = .lightGray
        button.isBordered = false
        button.action = #selector(openMenu)
        button.target = self
        
        self.addSubview(button)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.gridColor.set()
        let line = NSBezierPath()
        line.move(to: NSMakePoint(0, 0))
        line.line(to: NSMakePoint(self.frame.width, 0))
        line.lineWidth = 1
        line.stroke()
    }
    
    @objc func openMenu(_ sender: Any) {
        self.window?.setIsVisible(false)
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.titleView?.stringValue ?? ""])
    }
}
