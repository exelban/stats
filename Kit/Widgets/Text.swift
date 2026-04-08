//
//  Text.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 08/09/2024
//  Using Swift 5.0
//  Running on macOS 14.6
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//  

import Cocoa

public class TextWidget: WidgetWrapper {
    private var value: String = ""
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        super.init(.text, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: 30 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        if preview {
            self.value = "Text"
        }
        
        self.canDrawConcurrently = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        var value: String = ""
        self.queue.sync {
            value = self.value
        }

        if value.isEmpty {
            self.setWidth(0)
            return
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let lines = value.components(separatedBy: "\n")
        if lines.count >= 2 {
            // Two-line mode: small label on top, larger value below
            let topSize: CGFloat = 7
            let bottomSize: CGFloat = 10
            let totalHeight = topSize + bottomSize + 2

            let topAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: topSize, weight: .light),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: style
            ]
            let bottomAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: bottomSize, weight: .medium),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: style
            ]

            let topStr = NSAttributedString(string: lines[0], attributes: topAttrs)
            let bottomStr = NSAttributedString(string: lines[1], attributes: bottomAttrs)

            let topWidth = topStr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).width
            let bottomWidth = bottomStr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).width
            let maxWidth = max(topWidth, bottomWidth)
            let width = (maxWidth + Constants.Widget.margin.x * 2).roundedUpToNearestTen()

            let baseY = (Constants.Widget.height - totalHeight) / 2
            let topRect = CGRect(x: Constants.Widget.margin.x, y: baseY + bottomSize + 2, width: width - Constants.Widget.margin.x * 2, height: topSize + 2)
            let bottomRect = CGRect(x: Constants.Widget.margin.x, y: baseY, width: width - Constants.Widget.margin.x * 2, height: bottomSize + 2)

            topStr.draw(with: topRect)
            bottomStr.draw(with: bottomRect)

            self.setWidth(width)
        } else {
            // Single-line mode (original)
            let valueSize: CGFloat = 12
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
                NSAttributedString.Key.foregroundColor: NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            let attributedString = NSAttributedString(string: value, attributes: stringAttributes)
            let size = attributedString.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            let width = (size.width+Constants.Widget.margin.x*2).roundedUpToNearestTen()
            let origin: CGPoint = CGPoint(x: Constants.Widget.margin.x, y: ((Constants.Widget.height-valueSize-1)/2))
            let rect = CGRect(x: origin.x, y: origin.y, width: width - (Constants.Widget.margin.x*2), height: valueSize)
            attributedString.draw(with: rect)

            self.setWidth(width)
        }
    }
    
    public func setValue(_ newValue: String) {
        guard self.value != newValue else { return }
        self.value = newValue
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    static public func parseText(_ raw: String) -> [KeyValue_t] {
        var pairs: [KeyValue_t] = []
        do {
            let regex = try NSRegularExpression(pattern: "(\\$[a-zA-Z0-9_]+)(?:\\.([a-zA-Z0-9_]+))?")
            let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: raw) {
                    let key = String(raw[keyRange])
                    let value: String?
                    if match.range(at: 2).location != NSNotFound, let valueRange = Range(match.range(at: 2), in: raw) {
                        value = String(raw[valueRange])
                    } else {
                        value = nil
                    }
                    pairs.append(KeyValue_t(key: key, value: value ?? ""))
                }
            }
        } catch {
            print("Error creating regex: \(error.localizedDescription)")
        }
        return pairs
    }
}
