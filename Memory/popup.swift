//
//  popup.swift
//  Memory
//
//  Created by Serhiy Mytrovtsiy on 18/04/2020.
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
    private let secondHeight: CGFloat = 92 // -26
    
    private var totalField: NSTextField? = nil
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var activeField: NSTextField? = nil
    private var inactiveField: NSTextField? = nil
    private var wiredField: NSTextField? = nil
    private var compressedField: NSTextField? = nil
    
    private var chart: LineChartView? = nil
    private var ready: Bool = false
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: firstHeight + secondHeight + (Constants.Popup.margins*2)))
        
        initFirstView()
        initOverview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initFirstView() {
        let rightWidth: CGFloat = 116
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.firstHeight, width: self.frame.width, height: self.firstHeight))
        
        let leftPanel = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width - rightWidth - Constants.Popup.margins, height: view.frame.height))
        
        self.chart = LineChartView(frame: NSRect(x: 4, y: 3, width: leftPanel.frame.width, height: leftPanel.frame.height), num: 120)
        leftPanel.addSubview(self.chart!)
        
        let rightPanel: NSView = NSView(frame: NSRect(x: view.frame.width - rightWidth, y: 0, width: rightWidth, height: view.frame.height))
        self.activeField = addFirstRow(mView: rightPanel, y: ((rightPanel.frame.height - 16)/2)+29, title: "Active:", value: "")
        self.inactiveField = addFirstRow(mView: rightPanel, y: (rightPanel.frame.height - 16)/2+10, title: "Inactive:", value: "")
        self.wiredField = addFirstRow(mView: rightPanel, y: ((rightPanel.frame.height - 16)/2)-10, title: "Wired:", value: "")
        self.compressedField = addFirstRow(mView: rightPanel, y: ((rightPanel.frame.height - 16)/2)-29, title: "Compressed:", value: "")
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        self.addSubview(view)
    }
    
    private func initOverview() {
        let y: CGFloat = self.frame.height - self.firstHeight - self.secondHeight - (Constants.Popup.margins*1)
        let view: NSView = NSView(frame: NSRect(x: 0, y: y, width: self.frame.width, height: self.secondHeight))
        
        addTitleSeparator("Overview", view)
        
        self.totalField = addSecondRow(mView: view, y: 44, title: "Total:", value: "")
        self.usedField = addSecondRow(mView: view, y: 22, title: "Used:", value: "")
        self.freeField = addSecondRow(mView: view, y: 0, title: "Free:", value: "")
        
        self.addSubview(view)
    }
    
    private func addTitleSeparator(_ title: String, _ mView: NSView) {
        let view: NSView = NSView(frame: NSRect(x: 0, y: mView.frame.height - 26, width: mView.frame.width, height: 26))
        
        let labelView: NSTextField = TextView(frame: NSRect(x: 0, y: (view.frame.height-15)/2, width: view.frame.width, height: 15))
        labelView.stringValue = title
        labelView.alignment = .center
        labelView.textColor = .secondaryLabelColor
        labelView.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        labelView.stringValue = title
        
        view.addSubview(labelView)
        mView.addSubview(view)
    }
    
    private func addFirstRow(mView: NSView, y: CGFloat, title: String, value: String) -> NSTextField {
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: y, width: mView.frame.width, height: 16))
        
        let labelWidth = title.widthOfString(usingFont: .systemFont(ofSize: 10, weight: .light)) + 4
        let labelView: NSTextField = TextView(frame: NSRect(x: 0, y: 1.5, width: labelWidth, height: 13))
        labelView.stringValue = title
        labelView.alignment = .natural
        labelView.font = NSFont.systemFont(ofSize: 10, weight: .light)
        
        let valueView: NSTextField = TextView(frame: NSRect(x: labelWidth, y: 1, width: mView.frame.width - labelWidth, height: 14))
        valueView.stringValue = value
        valueView.alignment = .right
        valueView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        
        rowView.addSubview(labelView)
        rowView.addSubview(valueView)
        mView.addSubview(rowView)
        
        return valueView
    }
    
    private func addSecondRow(mView: NSView, y: CGFloat, title: String, value: String) -> NSTextField {
        let rowView: NSView = NSView(frame: NSRect(x: Constants.Popup.margins, y: y, width: mView.frame.width - (Constants.Popup.margins*2), height: 16))
        
        let labelWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .regular)) + 5
        let labelView: LabelField = LabelField(frame: NSRect(x: 0, y: 0.5, width: labelWidth, height: 15), title)
        let valueView: ValueField = ValueField(frame: NSRect(x: labelWidth, y: 0, width: rowView.frame.width - labelWidth, height: 16), value)
        
        rowView.addSubview(labelView)
        rowView.addSubview(valueView)
        mView.addSubview(rowView)
        
        return valueView
    }
    
    public func loadCallback(_ value: MemoryUsage) {
        DispatchQueue.main.async(execute: {
            if self.window!.isVisible || !self.ready {
                self.activeField?.stringValue = Units(bytes: Int64(value.active!)).getReadableMemory()
                self.inactiveField?.stringValue = Units(bytes: Int64(value.inactive!)).getReadableMemory()
                self.wiredField?.stringValue = Units(bytes: Int64(value.wired!)).getReadableMemory()
                self.compressedField?.stringValue = Units(bytes: Int64(value.compressed!)).getReadableMemory()

                self.totalField?.stringValue = Units(bytes: Int64(value.total!)).getReadableMemory()
                self.usedField?.stringValue = Units(bytes: Int64(value.used!)).getReadableMemory()
                self.freeField?.stringValue = Units(bytes: Int64(value.free!)).getReadableMemory()
                self.ready = true
            }
            
            self.chart?.addValue(value.usage!)
        })
    }
}
