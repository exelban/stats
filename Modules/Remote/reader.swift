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
    private var task: Task<Void, Never>?
    private let taskLock = NSLock()
    
    public override func setup() {
        self.interval = 60
    }
    
    public override func read() {
        guard SystemStats.shared.auth.hasCredentials() else {
            self.cancelPendingRead()
            self.callback(nil)
            return
        }
        
        self.taskLock.lock()
        self.task?.cancel()
        self.task = Task { [weak self] in
            do {
                async let machines = SystemStats.shared.fetchMachines()
                async let hosts = SystemStats.shared.fetchHosts()
                async let groups = SystemStats.shared.fetchGroups()
                async let order = SystemStats.shared.fetchAccountOrder()
                let (m, h, g, o) = try await (machines, hosts, groups, order)
                guard !Task.isCancelled, SystemStats.shared.isAuthorized else { return }
                self?.callback(RemoteSnapshot(machines: m, hosts: h, groups: g, order: o))
            } catch {
                // Keep the last snapshot during temporary network/authentication failures.
            }
        }
        self.taskLock.unlock()
    }
    
    public override func pause() {
        super.pause()
        self.cancelPendingRead()
    }
    
    public override func stop() {
        super.stop()
        self.cancelPendingRead()
    }
    
    public override func terminate() {
        self.cancelPendingRead()
    }
    
    internal func cancelPendingRead() {
        self.taskLock.lock()
        self.task?.cancel()
        self.task = nil
        self.taskLock.unlock()
    }
}
