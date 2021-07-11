//
//  Server.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 04/07/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

struct event: Codable {
    var ID: String
    
    var version: String
    var build: String
    var modules: [String]
    
    var device: String
    var os: String
    var language: String
}

public class Server {
    public static let shared = Server(url: URL(string: "https://api.serhiy.io/v1/stats")!)
    
    public var ID: String {
        get {
            return Store.shared.string(key: "id", defaultValue: UUID().uuidString)
        }
    }
    private let url: URL
    
    public init(url: URL) {
        self.url = url
        
        if !Store.shared.exist(key: "id") {
            Store.shared.set(key: "id", value: self.ID)
        }
    }
    
    public func sendEvent(modules: [String]) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let systemVersion = ProcessInfo().operatingSystemVersion
        
        let e = event(
            ID: self.ID,
            version: version ?? "unknown",
            build: build ?? "unknown",
            modules: modules, device: SystemKit.shared.modelName() ?? "unknown",
            os: systemVersion.getFullVersion(),
            language: Locale.current.languageCode ?? "unknown"
        )
        
        var request = URLRequest(url: self.url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(e)
        } catch let err {
            error("failed to encode json: \(err)")
        }
        
        let task = URLSession.shared.dataTask(with: request) { (_, _, err) in
            if err != nil {
                error("send report \(String(describing: err))")
            }
        }
        task.resume()
    }
}
