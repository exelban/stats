//
//  Memory.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 30/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class MemoryWidget: Widget {
    private var orderReversedState: Bool = false
    private var value: (Int64, Int64) = (0, 0)
    
    private let store: UnsafePointer<Store>?
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        self.store = store
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        let values = value.split(separator: ",").map{ (Int64($0) ) }
                        if values.count == 2 {
                            self.value.0 = values[0]!
                            self.value.1 = values[1]!
                        }
                    }
                }
            }
        }
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: 62, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.title = title
        self.type = .memory
        self.preview = preview
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.orderReversedState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_orderReversed", defaultValue: self.orderReversedState)
        }
        
        if self.preview {
            self.orderReversedState = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let letterWidth: CGFloat = 8
        let rowWidth: CGFloat = self.frame.width - Constants.Widget.margin - letterWidth
        let rowHeight: CGFloat = self.frame.height / 2
        
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        let attributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .light),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        let freeY: CGFloat = !self.orderReversedState ? rowHeight+1 : 1
        let usedY: CGFloat = !self.orderReversedState ? 1 : rowHeight+1
        
        var rect = CGRect(x: Constants.Widget.margin, y: freeY, width: letterWidth, height: rowHeight)
        var str = NSAttributedString.init(string: "F:", attributes: attributes)
        str.draw(with: rect)
        
        rect = CGRect(x: letterWidth, y: freeY, width: rowWidth, height: rowHeight)
        str = NSAttributedString.init(string: Units(bytes: self.value.0).getReadableMemory(), attributes: attributes)
        str.draw(with: rect)
        
        rect = CGRect(x: Constants.Widget.margin, y: usedY, width: letterWidth, height: rowHeight)
        str = NSAttributedString.init(string: "U:", attributes: attributes)
        str.draw(with: rect)
        
        rect = CGRect(x: letterWidth, y: usedY, width: rowWidth, height: rowHeight)
        str = NSAttributedString.init(string: Units(bytes: self.value.1).getReadableMemory(), attributes: attributes)
        str.draw(with: rect)
    }
    
    public func setValue(_ value: (Int64, Int64)) {
        self.value = value
        
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 1) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: "Reverse values order",
            action: #selector(toggleOrder),
            state: self.orderReversedState
        ))
        
        superview.addSubview(view)
    }
    
    @objc private func toggleOrder(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.orderReversedState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_orderReversed", value: self.orderReversedState)
        self.display()
    }
}
