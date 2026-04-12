//
//  PieChart.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 30/11/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class PieChart: WidgetWrapper {
    private var labelState: Bool = false
    private var monochromeState: Bool = false
    private var boxState: Bool = true
    private var dynamicMonochromeState: Bool = false
    private var pressureState: Bool = false
    
    private var chart: PieChartView = PieChartView(
        frame: NSRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.height,
            height: Constants.Widget.height
        ),
        segments: [], filled: true, drawValue: false
    )
    private var labelView: NSView? = nil
    
    private let size: CGFloat = Constants.Widget.height - (Constants.Widget.margin.y*2) + (Constants.Widget.margin.x*2)
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if config != nil {
            if let titleFromConfig = config!["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            if let box = config!["Box"] as? Bool {
                self.boxState = box
            }
        }
        
        super.init(.pieChart, title: widgetTitle, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: self.size,
            height: Constants.Widget.height - (Constants.Widget.margin.y*2)
        ))
        
        self.canDrawConcurrently = true
        
        if preview {
            if self.title == "CPU" {
                self.chart.setSegments([
                    ColorValue(0.16, color: NSColor.systemRed),
                    ColorValue(0.28, color: NSColor.systemBlue)
                ])
            } else if self.title == "RAM" {
                self.chart.setSegments([
                    ColorValue(0.36, color: NSColor.systemBlue),
                    ColorValue(0.12, color: NSColor.systemOrange),
                    ColorValue(0.08, color: NSColor.systemPink)
                ])
            } else if self.title == "Disk" {
                self.chart.setSegments([
                    ColorValue(0.86, color: NSColor.systemBlue)
                ])
            }
        } else {
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.monochromeState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_monochrome", defaultValue: self.monochromeState)
            self.boxState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            if self.title == "RAM" {
                self.pressureState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_pressure", defaultValue: self.pressureState)
            }
        }
        
        self.draw()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func draw() {
        let x: CGFloat = self.labelState ? 8 + Constants.Widget.spacing : 0
        
        self.labelView = WidgetLabelView(self.title, height: self.frame.height)
        self.labelView!.isHidden = !self.labelState
        
        self.addSubview(self.labelView!)
        self.addSubview(self.chart)
        
        self.chart.frame = NSRect(x: x, y: 0, width: self.frame.size.height, height: self.frame.size.height)
        
        self.setFrameSize(NSSize(width: self.size + x, height: self.frame.size.height))
        self.setWidth(self.size + x)

        self.chart.transparent = !self.boxState
    }
    
    public func setValue(_ list: [ColorValue]) {
        var segments = list
        var backgroundColor: NSColor = .systemBlue

        if self.title == "RAM" {
            let freeColor = SColor.fromString(
                Store.shared.string(key: "\(self.title)_freeColor", defaultValue: SColor.lightGray.key)
            ).additional as? NSColor
            backgroundColor = freeColor ?? .lightGray
        }
        
        if self.monochromeState {
            if self.dynamicMonochromeState {
                for i in 0..<segments.count {
                    if let color = segments[i].color {
                        let monochromeColor = self.boxState ? NSColor.widgetMonochromeBackground : NSColor.widgetMonochromeAccent
                        segments[i].color = monochromeColor.withAlphaComponent(color.alphaComponent)
                    }
                }
                if self.boxState {
                    backgroundColor = .widgetMonochromeAccent
                }
            } else {
                for i in 0..<segments.count {
                    if let color = segments[i].color {
                        segments[i].color = color.grayscaled()
                    }
                }
                if self.boxState {
                    backgroundColor = backgroundColor.grayscaled()
                }
            }
        }
        
        DispatchQueue.main.async(execute: {
            self.chart.color = backgroundColor
            self.chart.setSegments(segments)
        })
    }

    public func setDynamicMonochrome(_ value: Bool) {
        self.dynamicMonochromeState = value
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()

        var rows: [PreferencesRow] = [
            PreferencesRow(localizedString("Box"), component: switchView(
                action: #selector(self.toggleBox),
                state: self.boxState
            )),
            PreferencesRow(localizedString("Label"), component: switchView(
                action: #selector(self.toggleLabel),
                state: self.labelState
            )),
            PreferencesRow(localizedString("Monochrome accent"), component: switchView(
                action: #selector(self.toggleMonochrome),
                state: self.monochromeState
            ))
        ]

        if self.title == "RAM" {
            rows.append(PreferencesRow(localizedString("Show memory pressure"), component: switchView(
                action: #selector(self.togglePressure),
                state: self.pressureState
            )))
        }

        view.addArrangedSubview(PreferencesSection(rows))
        
        return view
    }
    
    @objc private func toggleBox(_ sender: NSControl) {
        self.boxState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        self.chart.transparent = !self.boxState
    }

    @objc private func toggleLabel(_ sender: NSControl) {
        self.labelState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
        
        let x = self.labelState ? 6 + Constants.Widget.spacing : 0
        self.labelView!.isHidden = !self.labelState
        self.chart.setFrameOrigin(NSPoint(x: x, y: 0))
        self.setWidth(self.labelState ? self.size+x : self.size)
    }
    
    @objc private func toggleMonochrome(_ sender: NSControl) {
        self.monochromeState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_monochrome", value: self.monochromeState)
    }

    @objc private func togglePressure(_ sender: NSControl) {
        self.pressureState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_pressure", value: self.pressureState)
    }
}
