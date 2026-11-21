//
//  reader.swift
//  Remote
//
//  Created by Serhiy Mytrovtsiy on 20/05/2026.
//  Using Swift 6.0.
//  Running on macOS 26.5.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Kit

public final class DataReader: Reader<RemoteSnapshot> {
    private struct Overview: Decodable {
        let machines: [RemoteMachine]
        let hosts: [RemoteHost]
    }
    
    private struct Removed: Decodable {
        let id: String
    }
    
    private var stream: RemoteEventStream?
    private var legacyTask: Task<Void, Never>?
    private var detailsTask: Task<Void, Never>?
    internal private(set) var detailsLoaded: Bool = false
    private var groups: [RemoteGroup]?
    private var lastGroupRequest: Date = .distantPast
    private var machineDetails: [String: RemoteMachine]?
    
    public override func setup() {
        self.value = nil
    }
    
    public override func start() {
        self.active = true
        self.read()
    }
    
    public override func read() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.active, self.stream == nil, SystemStats.shared.auth.hasCredentials() else { return }
            let stream = RemoteEventStream(path: "/v1/overview/sse", onRejection: { [weak self] status in
                guard let self else { return }
                if status == 404 {
                    self.startLegacyReader()
                } else {
                    self.detailsTask?.cancel()
                    self.detailsTask = nil
                    self.machineDetails = nil
                    self.groups = nil
                    self.detailsLoaded = false
                    self.publish(RemoteSnapshot(machines: [], hosts: [], groups: []))
                }
            }, onEvent: { [weak self] event, data in
                try self?.receive(event, data: data)
            })
            self.stream = stream
            stream.start()
        }
    }
    
    private func receive(_ event: String, data: Data) throws {
        guard self.active, SystemStats.shared.isAuthorized else { return }
        let decoder = JSONDecoder()
        if event == "snapshot" {
            let overview = try decoder.decode(Overview.self, from: data)
            let ids = Set(overview.machines.map { $0.id })
            self.machineDetails = self.machineDetails?.filter { ids.contains($0.key) }
            self.loadDetails()
            self.publish(RemoteSnapshot(machines: overview.machines.map(self.withDetails), hosts: overview.hosts, groups: self.groups ?? []))
            return
        }
        
        guard var snapshot = self.value else { return }
        switch event {
        case "machine.updated":
            let machine = try decoder.decode(RemoteMachine.self, from: data)
            snapshot.machines.removeAll { $0.id == machine.id }
            snapshot.machines.append(self.withDetails(machine))
        case "host.updated":
            let host = try decoder.decode(RemoteHost.self, from: data)
            snapshot.hosts.removeAll { $0.id == host.id }
            snapshot.hosts.append(host)
        case "machine.removed":
            let id = try decoder.decode(Removed.self, from: data).id
            self.machineDetails?.removeValue(forKey: id)
            snapshot.machines.removeAll { $0.id == id }
        case "host.removed":
            let id = try decoder.decode(Removed.self, from: data).id
            snapshot.hosts.removeAll { $0.id == id }
        default: return
        }
        self.publish(snapshot)
    }
    
    private func publish(_ snapshot: RemoteSnapshot) {
        self.value = snapshot
        self.callbackHandler(snapshot)
    }
    
    private func withDetails(_ machine: RemoteMachine) -> RemoteMachine {
        guard let details = self.machineDetails?[machine.id] else { return machine }
        return RemoteMachine(id: machine.id, name: machine.name, online: machine.online, groupID: machine.groupID,
                             lastSeenTS: details.lastSeenTS, details: details.details, modules: details.modules)
    }
    
    internal func loadDetails(refreshGroups: Bool = false) {
        guard SystemStats.shared.isAuthorized, self.detailsTask == nil else { return }
        let loadGroups = self.groups == nil || (refreshGroups && Date().timeIntervalSince(self.lastGroupRequest) >= 3600)
        let loadMachines = !self.active || self.machineDetails == nil
        guard loadGroups || loadMachines else { return }
        if loadGroups { self.lastGroupRequest = Date() }
        self.detailsTask = Task { @MainActor in
            async let groups = loadGroups ? try? SystemStats.shared.fetchGroups() : nil
            async let machines = loadMachines ? try? SystemStats.shared.fetchMachines() : nil
            let hosts = self.active ? nil : try? await SystemStats.shared.fetchHosts()
            let (g, m) = await (groups, machines)
            guard !Task.isCancelled, SystemStats.shared.isAuthorized else { return }
            self.detailsTask = nil
            self.detailsLoaded = true
            if let g { self.groups = g }
            if let m { self.machineDetails = Dictionary(m.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) }
            if self.active, var snapshot = self.value {
                snapshot.groups = self.groups ?? []
                snapshot.machines = snapshot.machines.map(self.withDetails)
                self.publish(snapshot)
            } else if !self.active, let m, let hosts {
                self.publish(RemoteSnapshot(machines: m, hosts: hosts, groups: self.groups ?? []))
            }
        }
    }
    
    private func startLegacyReader() {
        self.legacyTask = Task { @MainActor in
            while !Task.isCancelled && self.active {
                do {
                    async let machines = SystemStats.shared.fetchMachines()
                    async let hosts = SystemStats.shared.fetchHosts()
                    let (m, h) = try await (machines, hosts)
                    guard !Task.isCancelled, SystemStats.shared.isAuthorized else { return }
                    self.loadDetails()
                    self.publish(RemoteSnapshot(machines: m, hosts: h, groups: self.groups ?? []))
                } catch {
                    if Task.isCancelled { return }
                }
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }
    
    public override func pause() {
        super.pause()
        DispatchQueue.main.async { self.disconnect() }
    }
    
    public override func stop() {
        super.stop()
        DispatchQueue.main.async { self.disconnect() }
    }
    
    public override func terminate() {
        self.stop()
    }
    
    internal func signOut() {
        self.disconnect()
        self.detailsLoaded = false
        self.groups = nil
        self.machineDetails = nil
        self.value = nil
    }
    
    private func disconnect() {
        self.stream?.stop()
        self.stream = nil
        self.legacyTask?.cancel()
        self.legacyTask = nil
        self.detailsTask?.cancel()
        self.detailsTask = nil
    }
}
