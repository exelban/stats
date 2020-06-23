//
//  Sensors.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 17/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class SensorsWidget: Widget {
    private var labelState: Bool = false
    private let store: UnsafePointer<Store>?
    
    private var values: [String] = []
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        self.store = store
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Values"] as? String {
                        self.values = value.split(separator: ",").map{ (String($0) ) }
                    }
                }
            }
            
            if let label = configuration["Label"] as? Bool {
                self.labelState = label
            }
        }
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: Constants.Widget.width, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.title = title
        self.type = .sensors
        self.preview = preview
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.labelState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
        }
        
        if self.preview {
            self.labelState = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard self.values.count != 0 else {
            self.setWidth(1)
            return
        }
        
        let num: Int = Int(round(Double(self.values.count) / 2))
        let width: CGFloat = Constants.Widget.width * CGFloat(num)
        
        let rowWidth: CGFloat = Constants.Widget.width - (Constants.Widget.margin*2)
        let rowHeight: CGFloat = self.frame.height / 2
        
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        let attributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .light),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        var x: CGFloat = Constants.Widget.margin
        for i in 0..<num {
            if self.values.indices.contains(i*2) {
                let rect = CGRect(x: x, y: rowHeight+1, width: rowWidth, height: rowHeight)
                let str = NSAttributedString.init(string: self.values[i*2], attributes: attributes)
                str.draw(with: rect)
            }
            
            if self.values.indices.contains((i*2)+1) {
                let rect = CGRect(x: x, y: 1, width: rowWidth, height: rowHeight)
                let str = NSAttributedString.init(string: self.values[(i*2)+1], attributes: attributes)
                str.draw(with: rect)
            }
            
            x += Constants.Widget.width
        }
        
        self.setWidth(width)
    }
    
    public func setValues(_ values: [String]) {
        self.values = values
        
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
}
