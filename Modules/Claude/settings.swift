//
//  settings.swift
//  Claude
//
//  Created by Stats Claude Module
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private var updateIntervalValue: Int = 10
    private let title: String

    public var setInterval: ((_ value: Int) -> Void) = {_ in }

    public init(_ module: ModuleType) {
        self.title = module.stringValue
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)

        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))

        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.translatesAutoresizingMaskIntoConstraints = false
        self.spacing = Constants.Settings.margin
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
    }
}
