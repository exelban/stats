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

internal struct RemotePreview: Decodable {
    var cpu: String?
    var ram: String?
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

public struct RemoteSnapshot: Codable {
    public var machines: [RemoteMachine]
    public var hosts: [RemoteHost]
    public var groups: [RemoteGroup]
}

public struct RemoteHost: Codable {
    public let id: String
    public let type: String
    public let name: String?
    public let url: String
    public let group: String?
    private let groupID: String?
    public var displayGroupID: String? { self.groupID ?? self.group }
    public let checkedAt: String?
    private struct Probe: Codable {
        let timestamp: String?
    }
    private let lastProbe: Probe?
    internal var checkTimestamp: String? { self.checkedAt ?? self.lastProbe?.timestamp }
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
            guard let self else { return }
            self.callback(self.dataReader?.value)
        }
        self.popupView.loadCallback = { [weak self] in self?.dataReader?.loadDetails(refreshGroups: true) }
        self.settingsView.loadCallback = { [weak self] in self?.dataReader?.loadDetails(refreshGroups: true) }
        
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
            } else {
                self.dataReader?.signOut()
                self.callback(RemoteSnapshot(machines: [], hosts: [], groups: []))
            }
        }
    }
    
    private func callback(_ snapshot: RemoteSnapshot?) {
        guard let snapshot, self.dataReader != nil else { return }
        self.settingsView.update(snapshot)
        guard self.enabled else { return }
        if self.dataReader?.detailsLoaded == true || (snapshot.machines.isEmpty && snapshot.hosts.isEmpty) {
            self.popupView.callback(snapshot)
        }
        
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
    internal func fetchMachines() async throws -> [RemoteMachine] {
        try await self.fetchListAsync(path: "/v1/machine")
    }
    internal func fetchHosts(historyWindow: String = "") async throws -> [RemoteHost] {
        let path = historyWindow.isEmpty ? "/v1/host" : "/v1/host?history=\(historyWindow)"
        return try await self.fetchListAsync(path: path)
    }
    internal func fetchGroups() async throws -> [RemoteGroup] {
        try await self.fetchListAsync(path: "/v1/group")
    }
    private func fetchListAsync<T: Decodable>(path: String) async throws -> [T] {
        try JSONDecoder().decode([T].self, from: await self.fetchData(path: path))
    }
    
    private func fetchData(path: String) async throws -> Data {
        guard let url = URL(string: "\(SystemStats.host)\(path)") else { throw URLError(.badURL) }
        let (data, response) = try await self.authorizedData(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

public class RemoteEventStream: NSObject, URLSessionDataDelegate {
    private let path: String
    private let onEvent: (String, Data) throws -> Void
    private let onRejection: ((Int) -> Void)?
    
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var authorizationTask: Task<Void, Never>?
    private var connectionGeneration: UInt = 0
    private var rejectedToken: String?
    private var retriedAuthorization = false
    private var buffer = Data()
    private var stopped = false
    private var reconnectAttempts = 0
    
    private let delegateQueue = OperationQueue.main
    
    internal init(path: String, onRejection: ((Int) -> Void)? = nil, onEvent: @escaping (String, Data) throws -> Void) {
        self.path = path
        self.onRejection = onRejection
        self.onEvent = onEvent
        super.init()
    }
    
    public func start() {
        self.stopped = false
        self.retriedAuthorization = false
        self.rejectedToken = nil
        self.openConnection()
    }
    
    public func stop() {
        self.stopped = true
        self.connectionGeneration &+= 1
        self.authorizationTask?.cancel()
        self.authorizationTask = nil
        self.task?.cancel()
        self.task = nil
        self.session?.invalidateAndCancel()
        self.session = nil
        self.buffer.removeAll()
    }
    
    private func openConnection() {
        guard !self.stopped, let url = URL(string: "\(SystemStats.host)\(self.path)") else { return }
        self.connectionGeneration &+= 1
        let generation = self.connectionGeneration
        self.authorizationTask?.cancel()
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let rejectedToken = self.rejectedToken
        self.authorizationTask = Task { @MainActor [weak self] in
            do {
                let authorized = try await SystemStats.shared.authorizedRequest(request, rejectedToken: rejectedToken)
                guard let self, !self.stopped, self.connectionGeneration == generation, !Task.isCancelled else { return }
                self.rejectedToken = nil
                self.connect(authorized)
            } catch {
                guard let self, !self.stopped, self.connectionGeneration == generation, !Task.isCancelled else { return }
                if error is RemoteAuthError || error is CancellationError { return }
                self.scheduleReconnect()
            }
        }
    }
    
    private func connect(_ request: URLRequest) {
        let session: URLSession
        if let existing = self.session {
            session = existing
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 65
            config.timeoutIntervalForResource = .infinity
            session = URLSession(configuration: config, delegate: self, delegateQueue: self.delegateQueue)
            self.session = session
        }
        
        self.buffer.removeAll()
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard !self.stopped, dataTask === self.task else {
            completionHandler(.cancel)
            return
        }
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        if http.statusCode == 401 {
            completionHandler(.cancel)
            self.task = nil
            guard !self.retriedAuthorization else {
                self.stop()
                self.onRejection?(http.statusCode)
                return
            }
            self.retriedAuthorization = true
            self.rejectedToken = String((dataTask.originalRequest?.value(forHTTPHeaderField: "Authorization") ?? "").dropFirst(7))
            self.openConnection()
            return
        }
        guard http.statusCode == 200 else {
            completionHandler(.cancel)
            if [403, 404, 410].contains(http.statusCode) {
                self.stop()
                self.onRejection?(http.statusCode)
            }
            return
        }
        self.retriedAuthorization = false
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !self.stopped, dataTask === self.task else { return }
        self.buffer.append(data)
        let separator = Data("\n\n".utf8)
        while let range = self.buffer.range(of: separator) {
            let frame = self.buffer.subdata(in: 0..<range.lowerBound)
            self.buffer.removeSubrange(0..<range.upperBound)
            do {
                try self.parseFrame(frame)
            } catch {
                self.buffer.removeAll()
                dataTask.cancel()
                return
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !self.stopped, task === self.task else { return }
        self.task = nil
        self.scheduleReconnect()
    }
    
    private func scheduleReconnect() {
        let delay = min(pow(2.0, Double(self.reconnectAttempts)), 60.0)
        self.reconnectAttempts += 1
        let generation = self.connectionGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.stopped, self.connectionGeneration == generation else { return }
            self.openConnection()
        }
    }
    
    private func parseFrame(_ frame: Data) throws {
        guard let text = String(data: frame, encoding: .utf8) else { return }
        var event = "message"
        var data: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("event:") {
                event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                data.append(String(line.dropFirst(5)))
            }
        }
        guard !data.isEmpty else { return }
        try self.onEvent(event, Data(data.joined(separator: "\n").utf8))
        self.reconnectAttempts = 0
    }
}

internal final class RemoteMachineStream: RemoteEventStream {
    private struct Update: Decodable {
        let machineID: String
        let preview: RemotePreview?
    }
    
    private enum FrameKey: String, CodingKey {
        case snapshot
    }
    
    private enum Frame: Decodable {
        case snapshot([Update])
        case update(Update)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: FrameKey.self)
            if let updates = try container.decodeIfPresent([Update].self, forKey: .snapshot) {
                self = .snapshot(updates)
            } else {
                self = .update(try Update(from: decoder))
            }
        }
    }
    
    internal static let maxMachines = 100
    
    internal init(machineIDs: [String], onUpdate: @escaping (String, RemotePreview, Bool) -> Void) {
        let path = "/v1/machine/sse?machineIDs=" + machineIDs.joined(separator: ",")
        super.init(path: path) { _, data in
            switch try JSONDecoder().decode(Frame.self, from: data) {
            case .snapshot(let snapshot):
                for update in snapshot {
                    if let preview = update.preview { onUpdate(update.machineID, preview, true) }
                }
            case .update(let update):
                if let preview = update.preview { onUpdate(update.machineID, preview, false) }
            }
        }
    }
}
