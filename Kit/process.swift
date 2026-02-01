//
//  process.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 05/01/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Process_p {
    var pid: Int { get }
    var name: String { get }
    var icon: NSImage { get }
}

public typealias ProcessHeader = (title: String, color: NSColor?)

public class ProcessesView: NSStackView {
    public var count: Int {
        self.list.count
    }
    private var list: [ProcessView] = []
    private var colorViews: [ColorView] = []
    
    public init(frame: NSRect, values: [ProcessHeader], n: Int = 0) {
        super.init(frame: frame)
        
        self.orientation = .vertical
        self.spacing = 0
        
        let header = self.generateHeaderView(values)
        self.addArrangedSubview(header)
        
        for _ in 0..<n {
            let view = ProcessView(n: values.count)
            self.addArrangedSubview(view)
            self.list.append(view)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func generateHeaderView(_ values: [ProcessHeader]) -> NSView {
        let view = NSStackView()
        view.widthAnchor.constraint(equalToConstant: self.bounds.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: ProcessView.height).isActive = true
        view.orientation = .horizontal
        view.distribution = .fillProportionally
        view.spacing = 0
        
        let iconView: NSImageView = NSImageView()
        iconView.widthAnchor.constraint(equalToConstant: ProcessView.height).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: ProcessView.height).isActive = true
        view.addArrangedSubview(iconView)
        
        let titleField = LabelField()
        titleField.cell?.truncatesLastVisibleLine = true
        titleField.toolTip = localizedString("Process")
        titleField.stringValue = localizedString("Process")
        titleField.textColor = .tertiaryLabelColor
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addArrangedSubview(titleField)
        
        if values.count == 1, let v = values.first {
            let field = LabelField()
            field.cell?.truncatesLastVisibleLine = true
            field.toolTip = v.title
            field.stringValue = v.title
            field.alignment = .right
            field.textColor = .tertiaryLabelColor
            field.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            view.addArrangedSubview(field)
        } else {
            for v in values {
                if let color = v.color {
                    let container: NSView = NSView()
                    container.widthAnchor.constraint(equalToConstant: 60).isActive = true
                    container.heightAnchor.constraint(equalToConstant: ProcessView.height).isActive = true
                    let colorBlock: ColorView = ColorView(frame: NSRect(x: 48, y: 5, width: 12, height: 12), color: color, state: true, radius: 4)
                    colorBlock.toolTip = v.title
                    colorBlock.widthAnchor.constraint(equalToConstant: 12).isActive = true
                    colorBlock.heightAnchor.constraint(equalToConstant: 12).isActive = true
                    self.colorViews.append(colorBlock)
                    container.addSubview(colorBlock)
                    view.addArrangedSubview(container)
                }
            }
        }
        
        return view
    }
    
    public func setLock(_ newValue: Bool) {
        self.list.forEach{ $0.setLock(newValue) }
    }
    
    public func clear(_ symbol: String = "") {
        self.list.forEach{ $0.clear(symbol) }
    }
    
    public func set(_ idx: Int, _ process: Process_p, _ values: [String]) {
        if self.list.indices.contains(idx) {
            self.list[idx].set(process, values)
        }
    }
    
    public func setColor(_ idx: Int, _ newColor: NSColor) {
        if self.colorViews.indices.contains(idx) {
            self.colorViews[idx].setColor(newColor)
        }
    }
}

public class ProcessView: NSStackView {
    static let height: CGFloat = 22
    
    private var pid: Int? = nil
    private var lock: Bool = false
    
    private var imageView: NSImageView = NSImageView()
    private var killView: NSButton = NSButton()
    private var labelView: LabelField = {
        let view = LabelField()
        view.cell?.truncatesLastVisibleLine = true
        return view
    }()
    private var valueViews: [ValueField] = []
    
    public init(size: CGSize = CGSize(width: 264, height: 22), n: Int = 1) {
        var rect = NSRect(x: 2, y: 5, width: 12, height: 12)
        if size.height != 22 {
            rect = NSRect(x: 1, y: 3, width: 12, height: 12)
        }
        self.imageView = NSImageView(frame: rect)
        self.killView = NSButton(frame: rect)
        
        super.init(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        
        self.wantsLayer = true
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.spacing = 0
        self.layer?.cornerRadius = 3
        
        let imageBox: NSView = {
            let view = NSView()
            
            self.killView.bezelStyle = .regularSquare
            self.killView.translatesAutoresizingMaskIntoConstraints = false
            self.killView.imageScaling = .scaleNone
            self.killView.image = Bundle(for: type(of: self)).image(forResource: "cancel")!
            self.killView.contentTintColor = .lightGray
            self.killView.isBordered = false
            self.killView.action = #selector(self.kill)
            self.killView.target = self
            self.killView.toolTip = localizedString("Kill process")
            self.killView.focusRingType = .none
            self.killView.isHidden = true
            
            view.addSubview(self.imageView)
            view.addSubview(self.killView)
            
            return view
        }()
        
        self.addArrangedSubview(imageBox)
        self.addArrangedSubview(self.labelView)
        self.valuesViews(n).forEach{ self.addArrangedSubview($0) }
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        NSLayoutConstraint.activate([
            imageBox.widthAnchor.constraint(equalToConstant: self.bounds.height),
            imageBox.heightAnchor.constraint(equalToConstant: self.bounds.height),
            self.labelView.heightAnchor.constraint(equalToConstant: 16),
            self.widthAnchor.constraint(equalToConstant: self.bounds.width),
            self.heightAnchor.constraint(equalToConstant: self.bounds.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func valuesViews(_ n: Int) -> [NSView] {
        var list: [ValueField] = []
        
        for _ in 0..<n {
            let view: ValueField = ValueField()
            view.widthAnchor.constraint(equalToConstant: 68).isActive = true
            if n != 1 {
                view.font = NSFont.systemFont(ofSize: 10, weight: .regular)
            }
            list.append(view)
        }
        
        self.valueViews = list
        return list
    }
    
    public override func mouseEntered(with: NSEvent) {
        if self.lock {
            self.imageView.isHidden = true
            self.killView.isHidden = false
            return
        }
        self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.05)
    }
    
    public override func mouseExited(with: NSEvent) {
        if self.lock {
            self.imageView.isHidden = false
            self.killView.isHidden = true
            return
        }
        self.layer?.backgroundColor = .none
    }
    
    public override func mouseDown(with: NSEvent) {
        self.setLock(!self.lock)
    }
    
    fileprivate func set(_ process: Process_p, _ values: [String]) {
        if self.lock && process.pid != self.pid { return }
        
        self.labelView.stringValue = process.name
        values.enumerated().forEach({ self.valueViews[$0.offset].stringValue = $0.element })
        self.imageView.image = process.icon
        self.pid = process.pid
        self.toolTip = "pid: \(process.pid)"
    }
    
    fileprivate func clear(_ symbol: String = "") {
        self.labelView.stringValue = symbol
        self.valueViews.forEach({ $0.stringValue = symbol })
        self.imageView.image = nil
        self.pid = nil
        self.setLock(false)
        self.toolTip = symbol
    }
    
    fileprivate func setLock(_ state: Bool) {
        self.lock = state
        if self.lock {
            self.imageView.isHidden = true
            self.killView.isHidden = false
            self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.1)
        } else {
            self.imageView.isHidden = false
            self.killView.isHidden = true
            self.layer?.backgroundColor = .none
        }
    }
    
    @objc private func kill() {
        if let pid = self.pid {
            _ = syncShell("kill -9 \(pid)")
            self.clear()
            self.setLock(false)
        }
    }
}
