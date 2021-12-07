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
    
    var omit: Bool
}

public class Server {
    public static let shared = Server(url: URL(string: "")!)
    
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
    
    public func sendEvent(modules: [String], omit: Bool = false) {
    }
}
