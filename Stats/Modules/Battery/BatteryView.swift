//
//  BatteryView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 05/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import Cocoa

extension Battery {
    
    func initTab() {
        self.tabView.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: 10)
        
        makeMain()
        makeOverview()
        makeBattery()
        makePowerAdapter()
    }
    
    func makeMain() {
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: TabHeight - stackHeight*3 - 4, width: TabWidth, height: stackHeight*3))
        vertical.orientation = .vertical
        
        let level: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        level.orientation = .horizontal
        level.distribution = .equalCentering
        let levelLabel = LabelField(string: "Level")
        let levelValue = ValueField(string: "0 %")
        level.addView(levelLabel, in: .center)
        level.addView(levelValue, in: .center)
        
        let source: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        source.orientation = .horizontal
        source.distribution = .equalCentering
        let sourceLabel = LabelField(string: "Source")
        let sourceValue = ValueField(string: "AC Power")
        source.addView(sourceLabel, in: .center)
        source.addView(sourceValue, in: .center)
        
        let time: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        time.orientation = .horizontal
        time.distribution = .equalCentering
        let timeLabel = LabelField(string: "Time to charge")
        let timeValue = ValueField(string: "Calculating")
        time.addView(timeLabel, in: .center)
        time.addView(timeValue, in: .center)
        
        vertical.addSubview(level)
        vertical.addSubview(source)
        vertical.addSubview(time)
        
        self.tabView.view?.addSubview(vertical)
        
        (self.reader as! BatteryReader).usage.subscribe(observer: self) { (value, _) in
            levelValue.stringValue = "\(Int(value.capacity * 100)) %"
            sourceValue.stringValue = value.powerSource
            
            if value.powerSource == "Battery Power" {
                timeLabel.stringValue = "Time to discharge"
                if value.timeToEmpty != -1 && value.timeToEmpty != 0 {
                    timeValue.stringValue = Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds()
                }
            } else {
                timeLabel.stringValue = "Time to charge"
                if value.timeToCharge != -1 && value.timeToCharge != 0 {
                    timeValue.stringValue = Double(value.timeToCharge*60).printSecondsToHoursMinutesSeconds()
                }
            }

            if value.timeToEmpty == -1 || value.timeToEmpty == -1 {
                timeValue.stringValue = "Calculating"
            }
            
            if value.isCharged {
                timeValue.stringValue = "Fully charged"
            }
        }
    }
    
    func makeOverview() {
        let overviewLabel: NSView = NSView(frame: NSRect(x: 0, y: TabHeight - 102, width: TabWidth, height: 25))
        
        overviewLabel.wantsLayer = true
        overviewLabel.layer?.backgroundColor = NSColor(hexString: "#eeeeee", alpha: 0.5).cgColor
        
        let overviewText: NSTextField = NSTextField(string: "Overview")
        overviewText.frame = NSRect(x: 0, y: 0, width: TabWidth, height: overviewLabel.frame.size.height - 4)
        overviewText.isEditable = false
        overviewText.isSelectable = false
        overviewText.isBezeled = false
        overviewText.wantsLayer = true
        overviewText.textColor = .darkGray
        overviewText.canDrawSubviewsIntoLayer = true
        overviewText.alignment = .center
        overviewText.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
        overviewText.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        overviewLabel.addSubview(overviewText)
        self.tabView.view?.addSubview(overviewLabel)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 184, width: TabWidth, height: stackHeight*3))
        vertical.orientation = .vertical
        
        let cycles: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        cycles.orientation = .horizontal
        cycles.distribution = .equalCentering
        let cyclesLabel = LabelField(string: "Cycles")
        let cyclesValue = ValueField(string: "0")
        cycles.addView(cyclesLabel, in: .center)
        cycles.addView(cyclesValue, in: .center)
        
        let health: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        health.orientation = .horizontal
        health.distribution = .equalCentering
        let healthLabel = LabelField(string: "Health")
        let healthValue = ValueField(string: "Calculating")
        health.addView(healthLabel, in: .center)
        health.addView(healthValue, in: .center)
        
        let state: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        state.orientation = .horizontal
        state.distribution = .equalCentering
        let stateLabel = LabelField(string: "State")
        let stateValue = ValueField(string: "Calculating")
        state.addView(stateLabel, in: .center)
        state.addView(stateValue, in: .center)
        
        vertical.addSubview(cycles)
        vertical.addSubview(health)
        vertical.addSubview(state)
        
        self.tabView.view?.addSubview(vertical)
        
        (self.reader as! BatteryReader).usage.subscribe(observer: self) { (value, _) in
            cyclesValue.stringValue = "\(value.cycles)"
            stateValue.stringValue = value.state
            healthValue.stringValue = "\(value.health) %"
        }
    }
    
    func makeBattery() {
        let batteryLabel: NSView = NSView(frame: NSRect(x: 0, y: TabHeight - 202, width: TabWidth, height: 25))
        
        batteryLabel.wantsLayer = true
        batteryLabel.layer?.backgroundColor = NSColor(hexString: "#eeeeee", alpha: 0.5).cgColor
        
        let overviewText: NSTextField = NSTextField(string: "Battery")
        overviewText.frame = NSRect(x: 0, y: 0, width: TabWidth, height: batteryLabel.frame.size.height - 4)
        overviewText.isEditable = false
        overviewText.isSelectable = false
        overviewText.isBezeled = false
        overviewText.wantsLayer = true
        overviewText.textColor = .darkGray
        overviewText.canDrawSubviewsIntoLayer = true
        overviewText.alignment = .center
        overviewText.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
        overviewText.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        batteryLabel.addSubview(overviewText)
        self.tabView.view?.addSubview(batteryLabel)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: TabHeight - 273, width: TabWidth, height: stackHeight*3))
        vertical.orientation = .vertical
        
        let amperage: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        amperage.orientation = .horizontal
        amperage.distribution = .equalCentering
        let amperageLabel = LabelField(string: "Amperage")
        let amperageValue = ValueField(string: "0 mA")
        amperage.addView(amperageLabel, in: .center)
        amperage.addView(amperageValue, in: .center)
        
        let voltage: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        voltage.orientation = .horizontal
        voltage.distribution = .equalCentering
        let voltageLabel = LabelField(string: "Voltage")
        let voltageValue = ValueField(string: "0 V")
        voltage.addView(voltageLabel, in: .center)
        voltage.addView(voltageValue, in: .center)
        
        let temperature: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        temperature.orientation = .horizontal
        temperature.distribution = .equalCentering
        let temperatureLabel = LabelField(string: "Temperature")
        let temperatureValue = ValueField(string: "0 °C")
        temperature.addView(temperatureLabel, in: .center)
        temperature.addView(temperatureValue, in: .center)
        
        vertical.addSubview(amperage)
        vertical.addSubview(voltage)
        vertical.addSubview(temperature)
        
        self.tabView.view?.addSubview(vertical)
        (self.reader as! BatteryReader).usage.subscribe(observer: self) { (value, _) in
            amperageValue.stringValue = "\(value.amperage) mA"
            voltageValue.stringValue = "\(value.voltage.roundTo(decimalPlaces: 2)) V"
            temperatureValue.stringValue = "\(value.temperature) °C"
        }
    }
    
    func makePowerAdapter() {
        let powerAdapterLabel: NSView = NSView(frame: NSRect(x: 0, y: 52, width: TabWidth, height: 25))
        
        powerAdapterLabel.wantsLayer = true
        powerAdapterLabel.layer?.backgroundColor = NSColor(hexString: "#eeeeee", alpha: 0.5).cgColor
        
        let overviewText: NSTextField = NSTextField(string: "Power adapter")
        overviewText.frame = NSRect(x: 0, y: 0, width: TabWidth, height: powerAdapterLabel.frame.size.height - 4)
        overviewText.isEditable = false
        overviewText.isSelectable = false
        overviewText.isBezeled = false
        overviewText.wantsLayer = true
        overviewText.textColor = .darkGray
        overviewText.canDrawSubviewsIntoLayer = true
        overviewText.alignment = .center
        overviewText.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
        overviewText.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        powerAdapterLabel.addSubview(overviewText)
        self.tabView.view?.addSubview(powerAdapterLabel)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 4, width: TabWidth, height: stackHeight*2))
        vertical.orientation = .vertical
        
        let power: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        power.orientation = .horizontal
        power.distribution = .equalCentering
        let powerLabel = LabelField(string: "Power")
        let powerValue = ValueField(string: "0 W")
        power.addView(powerLabel, in: .center)
        power.addView(powerValue, in: .center)
        
        let charging: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        charging.orientation = .horizontal
        charging.distribution = .equalCentering
        let chargingLabel = LabelField(string: "Is charging")
        let chargingValue = ValueField(string: "No")
        charging.addView(chargingLabel, in: .center)
        charging.addView(chargingValue, in: .center)
        
        vertical.addSubview(power)
        vertical.addSubview(charging)
        
        self.tabView.view?.addSubview(vertical)
        
        (self.reader as! BatteryReader).usage.subscribe(observer: self) { (value, _) in
            powerValue.stringValue = value.powerSource == "Battery Power" ? "Not connected" : "\(value.ACwatts) W"
            chargingValue.stringValue = value.ACstatus ? "Yes" : "No"
        }
    }
}
