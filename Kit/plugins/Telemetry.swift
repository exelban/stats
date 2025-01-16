//
//  Telemetry.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 18/06/2023
//  Using Swift 5.0
//  Running on macOS 13.4
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

private struct Report: Codable {
    let id: UUID
    
    let version: String?
    let modules: [String]
    
    let device: String?
    let os: String?
    let language: String?
}

public class Telemetry {
    public var isEnabled: Bool {
        get {
            self._isEnabled
        }
        set {
            self.toggle(newValue)
        }
    }
    
    private var url: URL = URL(string: "https://api.mac-stats.com/telemetry")!
    
    private var _isEnabled: Bool = true
    
    private let id: UUID
    private let repeater = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.Telemetry")
    private var modules: UnsafePointer<[Module]>
    
    public init(_ modules: UnsafePointer<[Module]>) {
        self._isEnabled = Store.shared.bool(key: "telemetry", defaultValue: true)
        self.id = UUID(uuidString: Store.shared.string(key: "telemetry_id", defaultValue: UUID().uuidString)) ?? UUID()
        self.modules = modules
        
        if !Store.shared.exist(key: "telemetry_id") {
            Store.shared.set(key: "telemetry_id", value: self.id.uuidString)
            self.toggle(self.isEnabled)
        }
        
        self.report()
    }
    
    @objc public func report() {
        guard self.isEnabled else { return }
        
        let obj: Report = Report(
            id: self.id,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            modules: self.modules.pointee.filter({ $0.available && $0.enabled }).compactMap({ $0.name }),
            device: SystemKit.shared.device.model.id,
            os: SystemKit.shared.device.os?.version.getFullVersion(),
            language: Locale.current.languageCode
        )
        let jsonData = try? JSONEncoder().encode(obj)
        
        var request = URLRequest(url: self.url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request)
        task.resume()
    }
    
    private func toggle(_ newValue: Bool) {
        self._isEnabled = newValue
        Store.shared.set(key: "telemetry", value: newValue)
        
        self.repeater.invalidate()
        
        if newValue {
            self.repeater.repeats = true
            self.repeater.interval = 60 * 60 * 24
            self.repeater.schedule { (completion: @escaping NSBackgroundActivityScheduler.CompletionHandler) in
                self.report()
                completion(NSBackgroundActivityScheduler.Result.finished)
            }
        }
    }
}
