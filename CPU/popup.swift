//
//  popup.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 15/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

public class Popup: NSView {
    private let firstHeight: CGFloat = 90
    private let secondHeight: CGFloat = 102
    
    private var loadField: NSTextField? = nil
    private var frequencyField: NSTextField? = nil
    private var temperatureField: NSTextField? = nil
    
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: firstHeight + secondHeight + (Constants.Popup.margins*2)))
        
        initFirstView()
        initDescription()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initDescription() {
        let y: CGFloat = self.frame.height - self.firstHeight - self.secondHeight - (Constants.Popup.margins*1)
        let view: NSView = NSView(frame: NSRect(x: 0, y: y, width: self.frame.width, height: self.secondHeight))
        
        addTitleSeparator("Overview", view)
        
        self.systemField = addSecondRow(mView: view, y: 48, title: "System:", value: "12%")
        self.userField = addSecondRow(mView: view, y: 24, title: "User:", value: "12%")
        self.idleField = addSecondRow(mView: view, y: 0, title: "Idle:", value: "12%")
        
        self.addSubview(view)
    }
    
    private func initFirstView() {
        let rightWidth: CGFloat = 110
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.firstHeight, width: self.frame.width, height: self.firstHeight))
        
        let leftPanel = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width - rightWidth - Constants.Popup.margins, height: view.frame.height))
        leftPanel.wantsLayer = true
        leftPanel.layer?.backgroundColor = NSColor.yellow.cgColor
        
        let rightPanel: NSView = NSView(frame: NSRect(x: view.frame.width - rightWidth, y: 0, width: rightWidth, height: view.frame.height))
        self.loadField = addFirstRow(mView: rightPanel, y: ((rightPanel.frame.height - 16)/2)+20, title: "Load:", value: "")
        self.frequencyField = addFirstRow(mView: rightPanel, y: (rightPanel.frame.height - 16)/2, title: "Frequency:", value: "")
        self.temperatureField = addFirstRow(mView: rightPanel, y: ((rightPanel.frame.height - 16)/2)-20, title: "Temperature:", value: "")
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        self.addSubview(view)
    }
    
    private func addFirstRow(mView: NSView, y: CGFloat, title: String, value: String) -> NSTextField {
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: y, width: mView.frame.width, height: 16))
        
        let titleWidth = title.widthOfString(usingFont: .systemFont(ofSize: 10, weight: .light)) + 4
        let titleView: NSTextField = TextView(frame: NSRect(x: 0, y: 1.5, width: titleWidth, height: 13))
        titleView.stringValue = title
        titleView.alignment = .natural
        titleView.font = NSFont.systemFont(ofSize: 10, weight: .light)
        
        let valueView: NSTextField = TextView(frame: NSRect(x: titleWidth, y: 1, width: mView.frame.width - titleWidth, height: 14))
        valueView.stringValue = value
        valueView.alignment = .right
        valueView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        
        rowView.addSubview(titleView)
        rowView.addSubview(valueView)
        mView.addSubview(rowView)
        
        return valueView
    }
    
    private func addTitleSeparator(_ title: String, _ mView: NSView) {
        let view: NSView = NSView(frame: NSRect(x: 0, y: mView.frame.height - 30, width: mView.frame.width, height: 30))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0.4).cgColor
        
        let titleView: NSTextField = TextView(frame: NSRect(x: 0, y: (view.frame.height-15)/2, width: view.frame.width, height: 15))
        titleView.stringValue = title
        titleView.alignment = .center
        titleView.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleView.stringValue = title
        
        view.addSubview(titleView)
        mView.addSubview(view)
    }
    
    private func addSecondRow(mView: NSView, y: CGFloat, title: String, value: String) -> NSTextField {
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: y, width: mView.frame.width, height: 18))
        
        let titleWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .regular)) + 5
        let titleView: NSTextField = TextView(frame: NSRect(x: 0, y: 0.5, width: titleWidth, height: 16))
        titleView.stringValue = title
        titleView.textColor = .labelColor
        titleView.alignment = .natural
        titleView.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        
        let valueView: NSTextField = TextView(frame: NSRect(x: titleWidth, y: 0, width: mView.frame.width - titleWidth, height: 18))
        valueView.stringValue = value
        valueView.alignment = .right
        valueView.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        
        rowView.addSubview(titleView)
        rowView.addSubview(valueView)
        mView.addSubview(rowView)
        
        return valueView
    }
    
    public func loadCallback(_ value: CPULoad, freqValue: Double?, tempValue: Double?) {
        var frequency: String = "Unknown"
        var temperature: String = "Unknown"
        
        if tempValue != nil {
            let formatter = MeasurementFormatter()
            let measurement = Measurement(value: tempValue!, unit: UnitTemperature.celsius)
            temperature = formatter.string(from: measurement)
        }
        
        if freqValue != nil {
            frequency = "\((freqValue!/1000).rounded(toPlaces: 2))GHz"
        }
        
        DispatchQueue.main.async(execute: {
            self.frequencyField?.stringValue = frequency
            self.temperatureField?.stringValue = temperature
            
            self.systemField?.stringValue = "\(Int(value.systemLoad.rounded(toPlaces: 2) * 100))%"
            self.userField?.stringValue = "\(Int(value.userLoad.rounded(toPlaces: 2) * 100))%"
            self.idleField?.stringValue = "\(Int(value.idleLoad.rounded(toPlaces: 2) * 100))%"
            
            let v = Int(value.totalUsage.rounded(toPlaces: 2) * 100)
            self.loadField?.stringValue = "\(v)%"
        })
    }
}
