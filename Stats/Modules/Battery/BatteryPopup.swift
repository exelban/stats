//
//  BatteryPopup.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

extension Battery {
    public func initPopup() {
        self.popup.view.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
        
        self.makeMain()
        self.makeOverview()
        self.makeBattery()
        self.makePowerAdapter()
    }
    
    private func makeMain() {
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: TabHeight - stackHeight*3 - 4, width: TabWidth, height: stackHeight*3))
        vertical.orientation = .vertical
        
        let level: NSStackView = NSStackView(frame: NSRect(x: 11, y: stackHeight*2, width: TabWidth - 19, height: stackHeight))
        level.orientation = .horizontal
        level.distribution = .equalCentering
        let levelLabel = LabelField(string: "Level")
        self.levelValue = ValueField(string: "0 %")
        level.addView(levelLabel, in: .center)
        level.addView(self.levelValue, in: .center)
        
        let source: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        source.orientation = .horizontal
        source.distribution = .equalCentering
        let sourceLabel = LabelField(string: "Source")
        self.sourceValue = ValueField(string: "AC Power")
        source.addView(sourceLabel, in: .center)
        source.addView(self.sourceValue, in: .center)
        
        let time: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        time.orientation = .horizontal
        time.distribution = .equalCentering
        self.timeLabel = LabelField(string: "Time to charge")
        self.timeValue = ValueField(string: "Calculating")
        time.addView(self.timeLabel, in: .center)
        time.addView(self.timeValue, in: .center)
        
        vertical.addSubview(level)
        vertical.addSubview(source)
        vertical.addSubview(time)
        
        self.popup.view.view?.addSubview(vertical)
    }
    
    private func makeOverview() {
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
        self.popup.view.view?.addSubview(overviewLabel)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 184, width: TabWidth, height: stackHeight*3))
        vertical.orientation = .vertical
        
        let cycles: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        cycles.orientation = .horizontal
        cycles.distribution = .equalCentering
        let cyclesLabel = LabelField(string: "Cycles")
        self.cyclesValue = ValueField(string: "0")
        cycles.addView(cyclesLabel, in: .center)
        cycles.addView(self.cyclesValue, in: .center)
        
        let health: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        health.orientation = .horizontal
        health.distribution = .equalCentering
        let healthLabel = LabelField(string: "Health")
        self.healthValue = ValueField(string: "Calculating")
        health.addView(healthLabel, in: .center)
        health.addView(self.healthValue, in: .center)
        
        let state: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        state.orientation = .horizontal
        state.distribution = .equalCentering
        let stateLabel = LabelField(string: "State")
        self.stateValue = ValueField(string: "Calculating")
        state.addView(stateLabel, in: .center)
        state.addView(self.stateValue, in: .center)
        
        vertical.addSubview(cycles)
        vertical.addSubview(health)
        vertical.addSubview(state)
        
        self.popup.view.view?.addSubview(vertical)
    }
    
    private func makeBattery() {
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
        self.popup.view.view?.addSubview(batteryLabel)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: TabHeight - 273, width: TabWidth, height: stackHeight*3))
        vertical.orientation = .vertical
        
        let amperage: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        amperage.orientation = .horizontal
        amperage.distribution = .equalCentering
        let amperageLabel = LabelField(string: "Amperage")
        self.amperageValue = ValueField(string: "0 mA")
        amperage.addView(amperageLabel, in: .center)
        amperage.addView(self.amperageValue, in: .center)
        
        let voltage: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        voltage.orientation = .horizontal
        voltage.distribution = .equalCentering
        let voltageLabel = LabelField(string: "Voltage")
        self.voltageValue = ValueField(string: "0 V")
        voltage.addView(voltageLabel, in: .center)
        voltage.addView(self.voltageValue, in: .center)
        
        let temperature: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        temperature.orientation = .horizontal
        temperature.distribution = .equalCentering
        let temperatureLabel = LabelField(string: "Temperature")
        self.temperatureValue = ValueField(string: "0 °C")
        temperature.addView(temperatureLabel, in: .center)
        temperature.addView(self.temperatureValue, in: .center)
        
        vertical.addSubview(amperage)
        vertical.addSubview(voltage)
        vertical.addSubview(temperature)
        
        self.popup.view.view?.addSubview(vertical)
    }
    
    private func makePowerAdapter() {
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
        self.popup.view.view?.addSubview(powerAdapterLabel)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 4, width: TabWidth, height: stackHeight*2))
        vertical.orientation = .vertical
        
        let power: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        power.orientation = .horizontal
        power.distribution = .equalCentering
        let powerLabel = LabelField(string: "Power")
        self.powerValue = ValueField(string: "0 W")
        power.addView(powerLabel, in: .center)
        power.addView(self.powerValue, in: .center)
        
        let charging: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        charging.orientation = .horizontal
        charging.distribution = .equalCentering
        let chargingLabel = LabelField(string: "Is charging")
        self.chargingValue = ValueField(string: "No")
        charging.addView(chargingLabel, in: .center)
        charging.addView(self.chargingValue, in: .center)
        
        vertical.addSubview(power)
        vertical.addSubview(charging)
        
        self.popup.view.view?.addSubview(vertical)
    }
    
    public func popupUpdater(value: BatteryUsage) {
        if !self.popup.active && self.popup.initialized { return }
        self.popup.initialized = true
        
        // makeMain
        self.levelValue.stringValue = "\(Int(abs(value.capacity) * 100)) %"
        self.sourceValue.stringValue = value.powerSource
        if value.powerSource == "Battery Power" {
            self.timeLabel.stringValue = "Time to discharge"
            if value.timeToEmpty != -1 && value.timeToEmpty != 0 {
                self.timeValue.stringValue = Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds()
            }
        } else {
            self.timeLabel.stringValue = "Time to charge"
            if value.timeToCharge != -1 && value.timeToCharge != 0 {
                self.timeValue.stringValue = Double(value.timeToCharge*60).printSecondsToHoursMinutesSeconds()
            }
        }

        if value.timeToEmpty == -1 || value.timeToEmpty == -1 {
            self.timeValue.stringValue = "Calculating"
        }

        if value.isCharged {
            self.timeValue.stringValue = "Fully charged"
        }
        
        // makeOverview
        self.cyclesValue.stringValue = "\(value.cycles)"
        self.stateValue.stringValue = value.state
        self.healthValue.stringValue = "\(value.health) %"
        
        // makeBattery
        self.amperageValue.stringValue = "\(abs(value.amperage)) mA"
        self.voltageValue.stringValue = "\(value.voltage.roundTo(decimalPlaces: 2)) V"
        self.temperatureValue.stringValue = "\(value.temperature) °C"
        
        // makePowerAdapter
        self.powerValue.stringValue = value.powerSource == "Battery Power" ? "Not connected" : "\(value.ACwatts) W"
        self.chargingValue.stringValue = value.capacity > 0 ? "Yes" : "No"
    }
}
