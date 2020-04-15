//
//  ChartMarker.swift
//  StatsKit
//
//  Created by Serhiy Mytrovtsiy on 15/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Charts

public class ChartMarker: MarkerView {
    var text = ""
    
    public override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        super.refreshContent(entry: entry, highlight: highlight)
        text = String(entry.y)
    }
    
    public override func draw(context: CGContext, point: CGPoint) {
        super.draw(context: context, point: point)
        
        var drawAttributes = [NSAttributedString.Key : Any]()
        drawAttributes[.font] = NSFont.systemFont(ofSize: 13)
        drawAttributes[.foregroundColor] = NSColor.white
        drawAttributes[.backgroundColor] = NSColor.darkGray
        
        self.bounds.size = ("\(text)" as NSString).size(withAttributes: drawAttributes)
        self.offset = CGPoint(x: 0, y: self.bounds.size.height)
        
        let offset = self.offsetForDrawing(atPoint: point)
        drawText(text: "\(text)" as NSString, rect: CGRect(origin: CGPoint(x: point.x + offset.x, y: point.y + offset.y), size: self.bounds.size), withAttributes: drawAttributes)
    }
    
    func drawText(text: NSString, rect: CGRect, withAttributes attributes: [NSAttributedString.Key : Any]? = nil) {
        let size = text.size(withAttributes: attributes)
        let centeredRect = CGRect(x: rect.origin.x + (rect.size.width - size.width) / 2.0, y: rect.origin.y + (rect.size.height - size.height) / 2.0, width: size.width, height: size.height)
        text.draw(in: centeredRect, withAttributes: attributes)
    }
}
