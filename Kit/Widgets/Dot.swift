//
//  Dot.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 18/09/2022.
//  Using Swift 5.0.
//  Running on macOS 12.6.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class DotWidget: WidgetWrapper {
    private var value: NSColor = .systemGreen
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? Bool {
                        self.value = value ? .systemGreen : .systemRed
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var value: NSColor = .systemGreen
        self.queue.sync {
            value = self.value
        }
        
        let circle = NSBezierPath(ovalIn: CGRect(x: Constants.Widget.margin.x, y: (self.frame.height - 8)/2, width: 8, height: 8))
        value.set()
        circle.fill()
    }
    
    public func setValue(_ value: NSColor) {
        let updated = self.queue.sync { () -> Bool in
            guard self.value != value else { return false }
            self.value = value
            return true
        }
        guard updated else { return }
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
}
