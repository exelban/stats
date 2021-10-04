//
//  Label.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 30/03/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class Label: WidgetWrapper {
    private var label: String
    
    public init(title: String, config: NSDictionary, preview: Bool = false) {
        if let title = config["Title"] as? String {
            self.label = title
        } else {
            self.label = title
        }
        
        super.init(.label, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: 6 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let size: CGSize = CGSize(width: 6, height: self.frame.height / 3)
        var margin: CGPoint = CGPoint(x: Constants.Widget.margin.x, y: 0)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .regular),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        for char in String(self.label.prefix(3)).uppercased().reversed() {
            let rect = CGRect(x: margin.x, y: margin.y, width: size.width, height: size.height)
            let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
            str.draw(with: rect)
            margin.y += size.height
        }
    }
    
    public func setLabel(_ new: String) {
        if self.label == new {
            return
        }
        
        self.label = new
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
}
