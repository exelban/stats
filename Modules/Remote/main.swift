//
//  main.swift
//  Remote
//
//  Created by Serhiy Mytrovtsiy on 20/05/2026.
//  Using Swift 6.0.
//  Running on macOS 26.5.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public struct RemoteMachine: Codable {
    public let id: String
    public let name: String?
    public let online: Bool
    public let groupID: String?
    public let lastSeenTS: String?
    public let details: RemoteMachineDetails?
    public let modules: RemoteModules?
    
    public var displayName: String {
        if let n = self.name, !n.isEmpty { return n }
        if let model = self.details?.system?.model, !model.isEmpty { return model }
        return self.id
    }
    
    public var state: Bool {
        Store.shared.bool(key: "Remote_machine_\(self.id)", defaultValue: true)
    }
    
    public var uri: URL? {
        URL(string: "\(SystemStats.appHost)/machine/\(self.id)")
    }
    
    public var subtitle: String {
        guard let os = self.details?.system?.os else { return "" }
        if let name = os.name, let version = os.version { return "\(name) \(version)" }
        return os.name ?? ""
    }
}

public struct RemoteModules: Codable {
    public let cpu: [String: RemoteCPUModule]?
    public let ram: RemoteRAMModule?
    
    public var cpuUsage: Double? {
        guard let cpu = self.cpu else { return nil }
        let values = cpu.values.compactMap { $0.usage }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
    
    public var ramUsage: Double? {
        guard let ram = self.ram, ram.total > 0 else { return nil }
        return ram.used / ram.total
    }
}

public struct RemoteCPUModule: Codable {
    public let usage: Double?
}

public struct RemoteRAMModule: Codable {
    public let total: Double
    public let used: Double
}

public struct RemoteUpdate: Codable {
    public let online: Bool?
    public let modules: RemoteModules?
    public let lastSeenTS: String?
}

public struct RemoteGroup: Codable {
    public let id: String
    public let name: String
    public let parentID: String?
    public let order: Int?
}

public struct RemoteMachineDetails: Codable {
    public let system: RemoteMachineSystem?
}

public struct RemoteMachineSystem: Codable {
    public let platform: String?
    public let model: String?
    public let os: RemoteMachineOS?
}

public struct RemoteMachineOS: Codable {
    public let name: String?
    public let version: String?
}

public struct RemoteAccountOrder: Codable {
    public let machines: [String]
    public let hosts: [String]
}

public struct RemoteSnapshot: Codable {
    public let machines: [RemoteMachine]
    public let hosts: [RemoteHost]
    public let groups: [RemoteGroup]
    public let order: RemoteAccountOrder
}

private struct RemoteAccountResponse: Decodable {
    let settings: Settings?
    struct Settings: Decodable {
        let order: [String]?
        let hostsOrder: [String]?
    }
}

public struct RemoteHost: Codable {
    public let id: String
    public let type: String
    public let name: String?
    public let url: String
    public let group: String?
    public let lastStatus: String?
    public let lastLatencyMs: Int64?
    public let history: [RemoteHostBucket]?
    
    public var displayName: String {
        if let n = self.name, !n.isEmpty { return n }
        return self.url
    }
    
    public var state: Bool {
        Store.shared.bool(key: "Remote_host_\(self.id)", defaultValue: true)
    }
    
    public var color: NSColor {
        switch self.lastStatus?.lowercased() {
        case "up": return .systemGreen
        case "down": return .systemRed
        case "degraded": return .systemYellow
        default: return NSColor.tertiaryLabelColor.withAlphaComponent(0.3)
        }
    }
    
    public var uri: URL? {
        URL(string: "\(SystemStats.appHost)/host/\(self.id)")
    }
    
    public var subtitle: String {
        var parts = [self.type.uppercased()]
        if let latency = self.lastLatencyMs, latency > 0 {
            parts.append("\(latency) ms")
        }
        return parts.joined(separator: " · ")
    }
    
    public var status: Bool {
        switch self.lastStatus?.lowercased() {
        case "up": return true
        case "down", "degraded": return false
        default: return false
        }
    }
}

public struct RemoteHostBucket: Codable {
    public let ts: String
    public let status: String
    public let uptime: Double
    public let count: Int
}

public class Remote: Module {
    private let settingsView: Settings
    private let popupView: Popup
    private var dataReader: DataReader?
    
    public init() {
        self.settingsView = Settings(.remote)
        self.popupView = Popup(.remote)
        
        super.init(
            moduleType: .remote,
            popup: self.popupView,
            settings: self.settingsView,
        )
        
        self.dataReader = DataReader(.remote) { [weak self] snapshot in
            self?.callback(snapshot)
        }
        
        self.settingsView.toggleCallback = { [weak self] in
            self?.dataReader?.read()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleRemoteState), name: .remoteState, object: nil)
        
        self.setReaders([self.dataReader])
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .remoteState, object: nil)
    }
    
    @objc private func handleRemoteState(_ notification: Notification) {
        guard let auth = notification.userInfo?["auth"] as? Bool else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.popupView.authorizationStatus(auth)
            if auth {
                self.dataReader?.read()
            }
        }
    }
    
    private func callback(_ snapshot: RemoteSnapshot?) {
        guard let snapshot, self.enabled else { return }
        
        DispatchQueue.main.async(execute: {
            self.popupView.callback(snapshot)
        })
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: SWidget) in
            switch w.item {
            case let widget as DotWidget:
                widget.setValue(self.aggregateColor(snapshot))
            default: break
            }
        }
    }
    
    private func aggregateColor(_ snapshot: RemoteSnapshot) -> NSColor {
        var up = 0, down = 0, total = 0
        for m in snapshot.machines.filter({ $0.state }) where m.state {
            total += 1
            m.online ? (up += 1) : (down += 1)
        }
        for h in snapshot.hosts.filter({ $0.state }) where h.state {
            total += 1
            switch h.lastStatus?.lowercased() {
            case "up": up += 1
            case "down": down += 1
            default: break
            }
        }
        guard total > 0 else { return .systemGray }
        if up == total { return .systemGreen }
        if down == total { return .systemRed }
        return .systemOrange
    }
}

extension SystemStats {
    internal func fetchMachines() async -> [RemoteMachine] {
        await self.fetchListAsync(path: "/remote/machine")
    }
    internal func fetchHosts(historyWindow: String = "") async -> [RemoteHost] {
        let path = historyWindow.isEmpty ? "/host" : "/host?history=\(historyWindow)"
        return await self.fetchListAsync(path: path)
    }
    internal func fetchGroups() async -> [RemoteGroup] {
        await self.fetchListAsync(path: "/group")
    }
    internal func fetchAccountOrder() async -> RemoteAccountOrder {
        guard let request = self.authorizedGET("/account") else {
            return RemoteAccountOrder(machines: [], hosts: [])
        }
        guard let (data, response) = try? await self.session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let account = try? JSONDecoder().decode(RemoteAccountResponse.self, from: data) else {
            return RemoteAccountOrder(machines: [], hosts: [])
        }
        return RemoteAccountOrder(machines: account.settings?.order ?? [], hosts: account.settings?.hostsOrder ?? [])
    }
    
    private func fetchListAsync<T: Decodable>(path: String) async -> [T] {
        guard let request = self.authorizedGET(path) else { return [] }
        guard let (data, response) = try? await self.session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        if let list = try? JSONDecoder().decode([T].self, from: data) { return list }
        debug("fetch \(path) decode failed: \(String(data: data, encoding: .utf8) ?? "")")
        return []
    }
    
    private func authorizedGET(_ path: String) -> URLRequest? {
        guard self.isAuthorized, let url = URL(string: "\(SystemStats.host)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.auth.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    internal func fetchMachines(completion: @escaping ([RemoteMachine]) -> Void) {
        self.fetchList(path: "/remote/machine", completion: completion)
    }
    
    internal func fetchHosts(historyWindow: String? = nil, completion: @escaping ([RemoteHost]) -> Void) {
        var path = "/host"
        if let window = historyWindow, !window.isEmpty {
            path += "?history=\(window)"
        }
        self.fetchList(path: path, completion: completion)
    }
    
    internal func fetchGroups(completion: @escaping ([RemoteGroup]) -> Void) {
        self.fetchList(path: "/group", completion: completion)
    }
    
    internal func fetchAccountOrder(completion: @escaping (RemoteAccountOrder) -> Void) {
        guard self.isAuthorized, let url = URL(string: "\(SystemStats.host)/account") else {
            DispatchQueue.main.async { completion(RemoteAccountOrder(machines: [], hosts: [])) }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.auth.accessToken)", forHTTPHeaderField: "Authorization")
        
        self.session.dataTask(with: request) { data, response, _ in
            guard let data, let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let account = try? JSONDecoder().decode(RemoteAccountResponse.self, from: data) else {
                DispatchQueue.main.async { completion(RemoteAccountOrder(machines: [], hosts: [])) }
                return
            }
            let order = RemoteAccountOrder(
                machines: account.settings?.order ?? [],
                hosts: account.settings?.hostsOrder ?? []
            )
            DispatchQueue.main.async { completion(order) }
        }.resume()
    }
    
    internal func fetchList<T: Decodable>(path: String, completion: @escaping ([T]) -> Void) {
        guard self.isAuthorized, let url = URL(string: "\(SystemStats.host)\(path)") else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.auth.accessToken)", forHTTPHeaderField: "Authorization")
        
        self.session.dataTask(with: request) { data, response, _ in
            guard let data, let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            if let list = try? JSONDecoder().decode([T].self, from: data) {
                DispatchQueue.main.async { completion(list) }
                return
            }
            
            let body = String(data: data, encoding: .utf8) ?? ""
            debug("fetch \(path) decode failed: \(body)")
            DispatchQueue.main.async { completion([]) }
        }.resume()
    }
}

extension RemoteMachine {
    public func applying(_ update: RemoteUpdate) -> RemoteMachine {
        RemoteMachine(
            id: self.id,
            name: self.name,
            online: update.online ?? self.online,
            groupID: self.groupID,
            lastSeenTS: update.lastSeenTS ?? self.lastSeenTS,
            details: self.details,
            modules: update.modules ?? self.modules
        )
    }
}

public final class RemoteMachineStream: NSObject, URLSessionDataDelegate {
    private let machineID: String
    private let onUpdate: (RemoteUpdate) -> Void
    
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var stopped = false
    private var reconnectAttempts = 0
    
    public init(machineID: String, onUpdate: @escaping (RemoteUpdate) -> Void) {
        self.machineID = machineID
        self.onUpdate = onUpdate
        super.init()
    }
    
    public func start() {
        self.stopped = false
        self.openConnection()
    }
    
    public func stop() {
        self.stopped = true
        self.task?.cancel()
        self.task = nil
        self.session?.invalidateAndCancel()
        self.session = nil
        self.buffer.removeAll()
    }
    
    private func openConnection() {
        guard !self.stopped, SystemStats.shared.isAuthorized, let url = URL(string: "\(SystemStats.host)/remote/machine/\(self.machineID)/sse") else { return }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = .infinity
        config.timeoutIntervalForResource = .infinity
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(SystemStats.shared.auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.buffer.append(data)
        let separator = Data("\n\n".utf8)
        while let range = self.buffer.range(of: separator) {
            let frame = self.buffer.subdata(in: 0..<range.lowerBound)
            self.buffer.removeSubrange(0..<range.upperBound)
            self.parseFrame(frame)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !self.stopped else { return }
        let delay = min(pow(2.0, Double(self.reconnectAttempts)), 60.0)
        self.reconnectAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.stopped else { return }
            self.openConnection()
        }
    }
    
    private func parseFrame(_ frame: Data) {
        guard let text = String(data: frame, encoding: .utf8) else { return }
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }
            let jsonText = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard !jsonText.isEmpty,
                  let jsonData = jsonText.data(using: .utf8),
                  let update = try? JSONDecoder().decode(RemoteUpdate.self, from: jsonData) else { continue }
            self.reconnectAttempts = 0
            let cb = self.onUpdate
            DispatchQueue.main.async { cb(update) }
        }
    }
}
