//
//  Speed.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 24/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class SpeedWidget: WidgetWrapper {
    private var icon: String = "dots"
    private var valueState: Bool = true
    private var unitsState: Bool = true
    private var monochromeState: Bool = false
    private var valueColorState: String = "none"
    private var iconColorState: String = "default"
    private var valueAlignmentState: String = "right"
    private var modeState: String = "twoRows"
    private var reverseOrderState: Bool = false
    private var iconAlignmentState: String = "left"
    
    private var downloadColorState: SColor = .secondBlue
    private var uploadColorState: SColor = .secondRed
    
    private var symbols: [String] = ["U", "D"]
    
    private var uploadValue: Int64 = 0
    private var downloadValue: Int64 = 0
    
    private var width: CGFloat = 58
    
    private var valueColorView: NSPopUpButton? = nil
    private var valueAlignmentView: NSPopUpButton? = nil
    private var iconAlignmentView: NSPopUpButton? = nil
    private var iconColorView: NSPopUpButton? = nil
    
    private var downloadColor: (String) -> NSColor {{ state in
        if state == "none" { return .textColor }
        var color = self.monochromeState ? MonochromeColor.blue : (self.downloadColorState.additional as? NSColor ?? NSColor.systemBlue)
        if self.downloadValue < 1024 {
            if state == "transparent" {
                color = .clear
            } else if state == "default" {
                color = .textColor
            }
        }
        return color
    }}
    private var uploadColor: (String) -> NSColor {{ state in
        if state == "none" { return .textColor }
        var color = self.monochromeState ? MonochromeColor.red : (self.uploadColorState.additional as? NSColor ?? NSColor.red)
        if self.uploadValue < 1024 {
            if state == "transparent" {
                color = .clear
            } else if state == "default" {
                color = .textColor
            }
        }
        return color
    }}
    
    private var valueAlignment: NSTextAlignment {
        get {
            if let alignmentPair = Alignments.first(where: { $0.key == self.valueAlignmentState }) {
                return alignmentPair.additional as? NSTextAlignment ?? .left
            }
            return .left
        }
    }
    
    private var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(self.title)_base", defaultValue: "byte")) ?? .byte
    }
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        let widgetTitle: String = title
        if config != nil {
            if let symbols = config!["Symbols"] as? [String] { self.symbols = symbols }
            if let icon = config!["Icon"] as? String { self.icon = icon }
        }
        
        super.init(.speed, title: widgetTitle, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: width,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        self.canDrawConcurrently = true
        
        if !preview {
            self.valueState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_value", defaultValue: self.valueState)
            self.icon = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_icon", defaultValue: self.icon)
            self.unitsState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_units", defaultValue: self.unitsState)
            self.monochromeState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_monochrome", defaultValue: self.monochromeState)
            self.valueColorState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_valueColor", defaultValue: self.valueColorState)
            if self.valueColorState == "0" {
                self.valueColorState = "none"
            }
            self.downloadColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_downloadColor", defaultValue: self.downloadColorState.key))
            self.uploadColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_uploadColor", defaultValue: self.uploadColorState.key))
            self.valueAlignmentState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_valueAlignment", defaultValue: self.valueAlignmentState)
            self.modeState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_mode", defaultValue: self.modeState)
            self.reverseOrderState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_reverseOrder", defaultValue: self.reverseOrderState)
            self.iconAlignmentState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_iconAlignment", defaultValue: self.iconAlignmentState)
            self.iconColorState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_iconColor", defaultValue: self.iconColorState)
        }
        
        if preview {
            self.downloadValue = 8947141
            self.uploadValue = 478678
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var width: CGFloat = 0
        switch self.modeState {
        case "oneRow":
            width = self.drawOneRow()
        case "twoRows":
            width = self.drawTwoRows()
        default:
            width = 0
        }
        
        self.setWidth(width)
    }
    
    // MARK: - one row
    
    private func drawOneRow() -> CGFloat {
        var width: CGFloat = Constants.Widget.margin.x
        
        if self.reverseOrderState {
            width = self.drawRowItem(
                initWidth: width,
                symbol: self.symbols[1],
                iconColor: self.downloadColor(self.iconColorState),
                value: self.downloadValue,
                valueColor: self.downloadColor(self.valueColorState)
            )
            width += 4
            width = self.drawRowItem(
                initWidth: width,
                symbol: self.symbols[0],
                iconColor: self.uploadColor(self.iconColorState),
                value: self.uploadValue,
                valueColor: self.uploadColor(self.valueColorState)
            )
        } else {
            width = self.drawRowItem(
                initWidth: width,
                symbol: self.symbols[0],
                iconColor: self.uploadColor(self.iconColorState),
                value: self.uploadValue,
                valueColor: self.uploadColor(self.valueColorState)
            )
            width += 4
            width = self.drawRowItem(
                initWidth: width,
                symbol: self.symbols[1],
                iconColor: self.downloadColor(self.iconColorState),
                value: self.downloadValue,
                valueColor: self.downloadColor(self.valueColorState)
            )
        }
        
        return width + Constants.Widget.margin.x
    }
    
    private func drawRowItem(initWidth: CGFloat, symbol: String, iconColor: NSColor, value: Int64, valueColor: NSColor) -> CGFloat {
        var width = initWidth
        
        if self.iconAlignmentState == "left" {
            switch self.icon {
            case "dots":
                width += self.drawDot(CGPoint(x: width, y: 0), color: iconColor)
            case "arrows":
                width += self.drawArrow(CGPoint(x: width, y: 0), symbol: symbol, color: iconColor)
            case "chars":
                width += self.drawChar(CGPoint(x: width, y: 0), symbol: symbol, color: iconColor)
            default: break
            }
            width += self.valueState && self.icon != "none" ? 2 : 0
        }
        
        if self.valueState {
            width += self.drawValue(value, offset: CGPoint(x: width, y: 0), color: valueColor)
        }
        
        if self.iconAlignmentState == "right" {
            if self.valueState {
                width += 2
            }
            switch self.icon {
            case "dots":
                width += self.drawDot(CGPoint(x: width, y: 0), color: iconColor)
            case "arrows":
                width += self.drawArrow(CGPoint(x: width, y: 0), symbol: symbol, color: iconColor)
            case "chars":
                width += self.drawChar(CGPoint(x: width, y: 0), symbol: symbol, color: iconColor)
            default: break
            }
        }
        
        return width
    }
    
    private func drawValue(_ value: Int64, offset: CGPoint, color: NSColor) -> CGFloat {
        let rowWidth: CGFloat = self.unitsState ? 58 : 32
        let height: CGFloat = self.frame.height
        let style = NSMutableParagraphStyle()
        style.alignment = self.valueAlignment
        let size: CGFloat = 10
        
        let downloadStringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11, weight: .medium),
            NSAttributedString.Key.foregroundColor: color,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        let rect = CGRect(x: offset.x, y: (height-size)/2 + offset.y + 1, width: rowWidth - (Constants.Widget.margin.x*2), height: size)
        let value = NSAttributedString.init(
            string: Units(bytes: value).getReadableSpeed(base: base, omitUnits: !self.unitsState),
            attributes: downloadStringAttributes
        )
        value.draw(with: rect)
        
        return rowWidth
    }
    
    private func drawDot(_ offset: CGPoint, color: NSColor) -> CGFloat {
        var size: CGFloat = 8
        var height: CGFloat = self.frame.height
        
        if self.modeState == "twoRows" {
            size = 6
            height /= 2
        }
        
        var circle = NSBezierPath()
        circle = NSBezierPath(ovalIn: CGRect(x: offset.x, y: (height-size)/2 + offset.y, width: size, height: size))
        color.set()
        circle.fill()
        
        return size
    }
    
    private func drawArrow(_ offset: CGPoint, symbol: String, color: NSColor) -> CGFloat {
        let height = self.frame.height
        let size = height * 0.8
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth: CGFloat = 1
        let arrowSize: CGFloat = 3 + (scaleFactor/2)
        let x = arrowSize + (lineWidth / 2)
        let y = (height - size)/2
        
        var start: CGPoint = CGPoint()
        var end: CGPoint = CGPoint()
        if symbol == "D" {
            start = CGPoint(x: offset.x + x, y: size + y)
            end = CGPoint(x: offset.x + x, y: y)
        } else if symbol == "U" {
            start = CGPoint(x: offset.x + x, y: y)
            end = CGPoint(x: offset.x + x, y: size + y)
        }
        
        let arrow = NSBezierPath()
        arrow.addArrow(
            start: start,
            end: end,
            pointerLineLength: arrowSize,
            arrowAngle: CGFloat(Double.pi / 5)
        )
        
        color.set()
        arrow.lineWidth = lineWidth
        arrow.stroke()
        arrow.close()
        
        return arrowSize
    }
    
    private func drawChar(_ offset: CGPoint, symbol: String, color: NSColor) -> CGFloat {
        let rowHeight: CGFloat = self.frame.height
        let height: CGFloat = 10
        let downloadAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12, weight: .medium),
            NSAttributedString.Key.foregroundColor: color,
            NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
        ]
        let rect = CGRect(x: offset.x, y: offset.y + ((rowHeight-height)/2) + 1, width: 10, height: height)
        let str = NSAttributedString.init(string: symbol, attributes: downloadAttributes)
        str.draw(with: rect)
        
        return 10
    }
    
    // MARK: - two rows
    
    private func drawTwoRows() -> CGFloat {
        var width: CGFloat = 7
        var x: CGFloat = 7
        
        if self.iconAlignmentState == "right" {
            x = 0
        }
        if self.icon == "none" {
            x = 0
            width = 0
        }
        
        if self.valueState {
            let rowWidth: CGFloat = self.unitsState ? 48 : 30
            let rowHeight: CGFloat = self.frame.height / 2
            let style = NSMutableParagraphStyle()
            style.alignment = self.valueAlignment
            
            let downloadStringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .bold),
                NSAttributedString.Key.foregroundColor: self.downloadColor(self.valueColorState),
                NSAttributedString.Key.paragraphStyle: style
            ]
            let uploadStringAttributes = [
				NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .bold),
                NSAttributedString.Key.foregroundColor: self.uploadColor(self.valueColorState),
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let downloadY: CGFloat = self.reverseOrderState ? rowHeight + 1 : 1
            let uploadY: CGFloat = self.reverseOrderState ? 1 : rowHeight + 1
            
            var rect = CGRect(x: Constants.Widget.margin.x + x, y: downloadY, width: rowWidth - (Constants.Widget.margin.x*2), height: rowHeight)
            let download = NSAttributedString.init(
                string: Units(bytes: self.downloadValue).getReadableSpeed(base: base, omitUnits: !self.unitsState),
                attributes: downloadStringAttributes
            )
            download.draw(with: rect)
            
            rect = CGRect(x: Constants.Widget.margin.x + x, y: uploadY, width: rowWidth - (Constants.Widget.margin.x*2), height: rowHeight)
            let upload = NSAttributedString.init(
                string: Units(bytes: self.uploadValue).getReadableSpeed(base: base, omitUnits: !self.unitsState),
                attributes: uploadStringAttributes
            )
            upload.draw(with: rect)
            
            width += rowWidth
        }
        
        switch self.icon {
        case "dots":
            self.drawDots(width)
        case "arrows":
            self.drawArrows(width)
        case "chars":
            self.drawChars(width)
        default: break
        }
        
        return width
    }
    
    private func drawDots(_ width: CGFloat) {
        let rowHeight: CGFloat = self.frame.height / 2
        let size: CGFloat = 6
        let y: CGFloat = (rowHeight-size)/2
        let x: CGFloat = self.iconAlignmentState == "left" ? Constants.Widget.margin.x : Constants.Widget.margin.x+(width-6)
        let downloadY: CGFloat = self.reverseOrderState ? 10.5 : y-0.2
        let uploadY: CGFloat = self.reverseOrderState ? y-0.2 : 10.5
        
        var downloadCircle = NSBezierPath()
        downloadCircle = NSBezierPath(ovalIn: CGRect(x: x, y: downloadY, width: size, height: size))
        self.downloadColor(self.iconColorState).set()
        downloadCircle.fill()
        
        var uploadCircle = NSBezierPath()
        uploadCircle = NSBezierPath(ovalIn: CGRect(x: x, y: uploadY, width: size, height: size))
        self.uploadColor(self.iconColorState).set()
        uploadCircle.fill()
    }
    
    private func drawArrows(_ width: CGFloat) {
        let arrowAngle = CGFloat(Double.pi / 5)
        let half = self.frame.size.height / 2
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth: CGFloat = 1
        let arrowSize: CGFloat = 3 + (scaleFactor/2)
        var x = Constants.Widget.margin.x + arrowSize + (lineWidth / 2)
        if self.iconAlignmentState == "right" {
            x += (width-7)
        }
        
        let downloadYStart: CGFloat = self.reverseOrderState ? self.frame.size.height : half - Constants.Widget.spacing/2
        let downloadYEnd: CGFloat = self.reverseOrderState ? (half + Constants.Widget.spacing/2)+1 : 1
        
        let uploadYStart: CGFloat = self.reverseOrderState ? 0 : half + Constants.Widget.spacing/2
        let uploadYEnd: CGFloat = self.reverseOrderState ? (half - Constants.Widget.spacing/2)-1 : self.frame.size.height-1
        
        let downloadArrow = NSBezierPath()
        downloadArrow.addArrow(
            start: CGPoint(x: x, y: downloadYStart),
            end: CGPoint(x: x, y: downloadYEnd),
            pointerLineLength: arrowSize,
            arrowAngle: arrowAngle
        )
        
        self.downloadColor(self.iconColorState).set()
        downloadArrow.lineWidth = lineWidth
        downloadArrow.stroke()
        downloadArrow.close()
        
        let uploadArrow = NSBezierPath()
        uploadArrow.addArrow(
            start: CGPoint(x: x, y: uploadYStart),
            end: CGPoint(x: x, y: uploadYEnd),
            pointerLineLength: arrowSize,
            arrowAngle: arrowAngle
        )
        
        self.uploadColor(self.iconColorState).set()
        uploadArrow.lineWidth = lineWidth
        uploadArrow.stroke()
        uploadArrow.close()
    }
    
    private func drawChars(_ width: CGFloat) {
        let rowHeight: CGFloat = self.frame.height / 2
        let downloadY: CGFloat = self.reverseOrderState ? rowHeight+1 : 1
        let uploadY: CGFloat = self.reverseOrderState ? 1 : rowHeight+1
        let x: CGFloat = self.iconAlignmentState == "left" ? Constants.Widget.margin.x : Constants.Widget.margin.x+(width-6)
        
        if self.symbols.count > 1 {
            let downloadAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .medium),
                NSAttributedString.Key.foregroundColor: self.downloadColor(self.iconColorState),
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            let rect = CGRect(x: x, y: downloadY, width: 8, height: rowHeight)
            let str = NSAttributedString.init(string: self.symbols[1], attributes: downloadAttributes)
            str.draw(with: rect)
        }
        
        if !self.symbols.isEmpty {
            let uploadAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .medium),
                NSAttributedString.Key.foregroundColor: self.uploadColor(self.iconColorState),
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            let rect = CGRect(x: x, y: uploadY, width: 8, height: rowHeight)
            let str = NSAttributedString.init(string: self.symbols[0], attributes: uploadAttributes)
            str.draw(with: rect)
        }
    }
    
    // MARK: - settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        let valueAlignment = selectView(
            action: #selector(self.toggleValueAlignment),
            items: Alignments,
            selected: self.valueAlignmentState
        )
        valueAlignment.isEnabled = self.valueState
        self.valueAlignmentView = valueAlignment
        
        let iconAlignment = selectView(
            action: #selector(self.toggleIconAlignment),
            items: Alignments.filter({ $0.key != "center" }),
            selected: self.iconAlignmentState
        )
        iconAlignment.isEnabled = self.icon != "none"
        self.iconAlignmentView = iconAlignment
        
        let iconColor = selectView(
            action: #selector(self.toggleIconColor),
            items: SpeedPictogramColor.filter({ $0.key != "none" }),
            selected: self.iconColorState
        )
        iconColor.isEnabled = self.icon != "none"
        self.iconColorView = iconColor
        
        let valueColor = selectView(
            action: #selector(self.toggleValueColor),
            items: SpeedPictogramColor,
            selected: self.valueColorState
        )
        valueColor.isEnabled = self.valueState
        self.valueColorView = valueColor
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Display mode"), component: selectView(
                action: #selector(self.changeDisplayMode),
                items: SensorsWidgetMode.filter({ $0.key == "oneRow" || $0.key == "twoRows"}),
                selected: self.modeState
            )),
            PreferencesRow(localizedString("Reverse order"), component: switchView(
                action: #selector(self.toggleReverseOrder),
                state: self.reverseOrderState
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Pictogram"), component: selectView(
                action: #selector(self.toggleIcon),
                items: SpeedPictogram,
                selected: self.icon
            )),
            PreferencesRow(localizedString("Colorize"), component: iconColor),
            PreferencesRow(localizedString("Alignment"), component: iconAlignment)
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Value"), component: switchView(
                action: #selector(self.toggleValue),
                state: self.valueState
            )),
            PreferencesRow(localizedString("Colorize value"), component: valueColor),
            PreferencesRow(localizedString("Alignment"), component: valueAlignment),
            PreferencesRow(localizedString("Units"), component: switchView(
                action: #selector(self.toggleUnits),
                state: self.unitsState
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Monochrome accent"), component: switchView(
                action: #selector(self.toggleMonochrome),
                state: self.monochromeState
            )),
            PreferencesRow(localizedString("Color of download"), component: selectView(
                action: #selector(self.toggleDownloadColor),
                items: SColor.allColors,
                selected: self.downloadColorState.key
            )),
            PreferencesRow(localizedString("Color of upload"), component: selectView(
                action: #selector(self.toggleUploadColor),
                items: SColor.allColors,
                selected: self.uploadColorState.key
            ))
        ]))
        
        return view
    }
    
    @objc private func changeDisplayMode(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.modeState = key
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_mode", value: key)
        self.display()
    }
    
    @objc private func toggleReverseOrder(_ sender: NSControl) {
        self.reverseOrderState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_reverseOrder", value: self.reverseOrderState)
        self.display()
    }
    
    @objc private func toggleValue(_ sender: NSControl) {
        self.valueState = controlState(sender)
        
        self.valueColorView?.isEnabled = self.valueState
        self.valueAlignmentView?.isEnabled = self.valueState
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_value", value: self.valueState)
        self.display()
    }
    
    @objc private func toggleUnits(_ sender: NSControl) {
        self.unitsState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_units", value: self.unitsState)
        self.display()
    }
    
    @objc private func toggleIcon(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.icon = key
        self.iconColorView?.isEnabled = self.icon != "none"
        self.iconAlignmentView?.isEnabled = self.icon != "none"
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_icon", value: key)
        self.display()
    }
    
    @objc private func toggleMonochrome(_ sender: NSControl) {
        self.monochromeState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_monochrome", value: self.monochromeState)
        self.display()
    }
    
    @objc private func toggleValueColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = SpeedPictogramColor.first(where: { $0.key == key }) {
            self.valueColorState = newColor.key
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_valueColor", value: key)
        self.display()
    }
    
    @objc private func toggleUploadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.uploadColorState = newValue
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_uploadColor", value: key)
    }
    @objc private func toggleDownloadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.downloadColorState = newValue
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_downloadColor", value: key)
    }
    
    public func setValue(upload: Int64, download: Int64) {
        var updated: Bool = false
        
        if self.downloadValue != download {
            self.downloadValue = abs(download)
            updated = true
        }
        if self.uploadValue != upload {
            self.uploadValue = abs(upload)
            updated = true
        }
        
        if updated {
            DispatchQueue.main.async(execute: {
                self.display()
            })
        }
    }
    
    @objc private func toggleValueAlignment(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newAlignment = Alignments.first(where: { $0.key == key }) {
            self.valueAlignmentState = newAlignment.key
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_valueAlignment", value: key)
        self.display()
    }
    
    @objc private func toggleIconAlignment(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newAlignment = Alignments.first(where: { $0.key == key }) {
            self.iconAlignmentState = newAlignment.key
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_iconAlignment", value: key)
        self.display()
    }
    
    @objc private func toggleIconColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = SpeedPictogramColor.first(where: { $0.key == key }) {
            self.iconColorState = newColor.key
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_iconColor", value: key)
        self.display()
    }
}
