//
//  Flag.swift
//  Kit
//
//  Created for Stats.
//  Using Swift 5.0.
//  Running on macOS 10.15+.
//

import Cocoa

public class FlagWidget: WidgetWrapper {
    private var flag: String = "🏳️"

    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        super.init(.flag, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: 18 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))

        if preview {
            self.flag = "🇺🇸"
        }

        self.canDrawConcurrently = true
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        var currentFlag: String = ""
        self.queue.sync {
            currentFlag = self.flag
        }

        let flagSize: CGFloat = 14
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: flagSize, weight: .regular),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attributedString = NSAttributedString(string: currentFlag, attributes: stringAttributes)
        let origin: CGPoint = CGPoint(x: Constants.Widget.margin.x, y: ((Constants.Widget.height-flagSize-1)/2))
        let rect = CGRect(x: origin.x, y: origin.y, width: self.frame.width - (Constants.Widget.margin.x*2), height: flagSize)
        attributedString.draw(with: rect)
    }

    public func setFlag(_ countryCode: String?) {
        let newFlag: String
        if let code = countryCode {
            newFlag = countryCodeToFlag(code)
        } else {
            newFlag = "🏳️"
        }

        guard self.flag != newFlag else { return }
        self.flag = newFlag
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
}
