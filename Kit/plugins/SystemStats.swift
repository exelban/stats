//
//  SystemStats.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 16/03/2025
//  Using Swift 6.0
//  Running on macOS 15.3
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//
// swiftlint:disable file_length

import Foundation
import Cocoa
import CoreAudio
import Security

public protocol RemoteType {
    func remote() -> Data?
}

public enum AccountPlan: String, Codable {
    case free
    case pro
    case team
}

public class SystemStats {
    public static let shared = SystemStats()
    static public var host = URL(string: "https://api.system-stats.com")!
    static public var authHost = URL(string: "https://oauth.system-stats.com")!
    static public var brokerHost = URL(string: "wss://broker.system-stats.com:8084/mqtt")!
    static public var appHost = URL(string: "https://app.system-stats.com")!
    
    public var monitoring: Bool {
        get { Store.shared.bool(key: "remote_monitoring", defaultValue: true) }
        set {
            Store.shared.set(key: "remote_monitoring", value: newValue)
            if !newValue {
                self.mqtt.discardMetrics()
            }
            if newValue {
                self.start()
                self.registerDevice(omitCooldown: true)
            } else if !self.control && !self.update {
                self.stop()
            }
        }
    }
    public var control: Bool {
        get { Store.shared.bool(key: "remote_control", defaultValue: false) }
        set {
            Store.shared.set(key: "remote_control", value: newValue)
            if newValue {
                self.start()
                self.registerDevice(omitCooldown: true)
            } else if !self.monitoring && !self.update {
                self.stop()
            }
        }
    }
    public var update: Bool {
        get { Store.shared.bool(key: "remote_update", defaultValue: false) }
        set {
            Store.shared.set(key: "remote_update", value: newValue)
            if newValue {
                self.start()
                self.registerDevice(omitCooldown: true)
            } else if !self.monitoring && !self.control {
                self.stop()
            }
        }
    }
    public let id: UUID
    public var isAuthorized: Bool = false
    public var auth: RemoteAuth = RemoteAuth()
    public var plan: AccountPlan?
    
    private let log: NextLog
    private var mqtt: MQTTManager = MQTTManager()
    public let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    
    private var lastSleepTime: Date?
    private var lastRegisterTime: Date?
    fileprivate let cooldownLock = NSLock()
    
    struct Details: Codable {
        let client: Client
        let system: System
        let hardware: Hardware
    }
    
    struct Client: Codable {
        let version: String
        let control: Bool
        let update: Bool
    }
    
    struct OS: Codable {
        let name: String?
        let version: String?
        let build: String?
    }
    
    struct System: Codable {
        let platform: String
        let vendor: String?
        let model: String?
        let modelID: String?
        let os: OS
        let arch: String?
    }
    
    struct Hardware: Codable {
        let cpu: cpu_s?
        let gpu: [gpu_s]?
        let ram: [dimm_s]?
        let disk: [disk_s]?
    }
    
    public init() {
        self.log = NextLog.shared.copy(category: "Remote")
        
        let id: UUID
        if Store.shared.exist(key: "remote_id"),
           let existing = UUID(uuidString: Store.shared.string(key: "remote_id", defaultValue: "")) {
            id = existing
            if Store.shared.exist(key: "telemetry_id") {
                Store.shared.remove("telemetry_id")
            }
        } else if Store.shared.exist(key: "telemetry_id"),
                  let migrated = UUID(uuidString: Store.shared.string(key: "telemetry_id", defaultValue: "")) {
            id = migrated
            Store.shared.set(key: "remote_id", value: id.uuidString)
            Store.shared.remove("telemetry_id")
        } else {
            id = UUID()
            Store.shared.set(key: "remote_id", value: id.uuidString)
        }
        self.id = id
        
        self.mqtt.commandCallback = { [weak self] cmd, payload in
            self?.command(cmd: cmd, payload: payload)
        }
        self.mqtt.registerCallback = { [weak self] in
            self?.registerDevice()
        }
        self.mqtt.unregisterHandler = { [weak self] in
            guard let self else { return }
            info("Unregistered from MQTT broker, stopping Remote...", log: self.log)
            self.logout()
        }
        
        if self.auth.hasCredentials() {
            info("Found auth credentials for remote monitoring, starting Remote...", log: self.log)
            self.start()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.successLogin), name: .remoteLoginSuccess, object: nil)
    }
    
    deinit {
        self.mqtt.disconnect()
        NotificationCenter.default.removeObserver(self, name: .remoteLoginSuccess, object: nil)
    }
    
    public func login() {
        self.auth.login { url in
            guard let url else {
                error("Empty url when try to login", log: self.log)
                return
            }
            debug("Open \(url) to login to Stats Remote", log: self.log)
            NSWorkspace.shared.open(url)
        }
    }
    
    public func logout() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.logout() }
            return
        }
        self.auth.logout()
        self.mqtt.disconnect()
        self.isAuthorized = false
        debug("Logout successfully from Stats Remote", log: self.log)
        NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized])
    }
    
    public func deregister() {
        guard let url = URL(string: "\(SystemStats.host)/v1/machine/\(SystemStats.shared.id.uuidString)/deregister") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SystemStats.shared.auth.accessToken)", forHTTPHeaderField: "Authorization")
        
        self.authorizedData(for: request) { [weak self] data, response, error in
            guard let self else { return }
            if error is CancellationError { return }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                debug("Deregistered device: \(SystemStats.shared.id.uuidString)", log: self.log)
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                debug("Deregister remote failed (\(statusCode)): \(bodyString)", log: self.log)
            }
            self.logout()
        }
    }
    
    public func send(key: String, value: Any) {
        guard self.monitoring && self.isAuthorized, let v = value as? RemoteType, let data = v.remote() else { return }
        self.mqtt.publishMetric(key: key, data: data)
    }
    
    @objc private func successLogin() {
        self.isAuthorized = true
        NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized])
        self.mqtt.connect()
        debug("Login successfully on Stats Remote", log: self.log)
    }
    
    public func start() {
        self.mqtt.connect()
    }
    
    fileprivate func authorize(rejectedToken: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        let generation = self.auth.generation
        self.auth.authorize(rejectedToken: rejectedToken) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.auth.generation == generation else {
                    completion(.failure(CancellationError()))
                    return
                }
                let authorized: Bool?
                switch result {
                case .success: authorized = true
                case .failure(RemoteAuthError.unauthorized): authorized = false
                case .failure: authorized = nil
                }
                if let authorized, self.isAuthorized != authorized {
                    self.isAuthorized = authorized
                    NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": authorized])
                }
                completion(result)
            }
        }
    }
    
    public func authorizedRequest(_ request: URLRequest, rejectedToken: String? = nil) async throws -> URLRequest {
        let generation = self.auth.generation
        let token: String = try await withCheckedThrowingContinuation { continuation in
            self.authorize(rejectedToken: rejectedToken) { continuation.resume(with: $0) }
        }
        try Task.checkCancellation()
        guard self.auth.generation == generation else { throw CancellationError() }
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    public func authorizedData(for request: URLRequest) async throws -> (Data, URLResponse) {
        let generation = self.auth.generation
        var request = try await self.authorizedRequest(request)
        var result = try await self.session.data(for: request)
        guard self.auth.generation == generation else { throw CancellationError() }
        if (result.1 as? HTTPURLResponse)?.statusCode == 401 {
            let token = String((request.value(forHTTPHeaderField: "Authorization") ?? "").dropFirst(7))
            request = try await self.authorizedRequest(request, rejectedToken: token)
            result = try await self.session.data(for: request)
            guard self.auth.generation == generation else { throw CancellationError() }
        }
        return result
    }
    
    private func authorizedData(for request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        Task {
            do {
                let (data, response) = try await self.authorizedData(for: request)
                completion(data, response, nil)
            } catch {
                completion(nil, nil, error)
            }
        }
    }
    
    private func stop() {
        self.mqtt.disconnect()
        NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized])
    }
    
    public func terminate() {
        self.mqtt.disconnect()
    }
    
    private func registerDevice(omitCooldown: Bool = false) {
        let oneHour: TimeInterval = 3600
        let now = Date()
        self.cooldownLock.lock()
        if let lastTime = self.lastRegisterTime, !omitCooldown && now.timeIntervalSince(lastTime) < oneHour {
            self.cooldownLock.unlock()
            debug("Device registration skipped: cooldown period not met", log: self.log)
            return
        }
        self.lastRegisterTime = now
        self.cooldownLock.unlock()
        
        guard let url = URL(string: "\(SystemStats.host)/v1/machine") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SystemStats.shared.auth.accessToken)", forHTTPHeaderField: "Authorization")
        
        struct RegisterPayload: Codable {
            let id: String
            let details: SystemStats.Details
        }
        
        let payload = RegisterPayload(
            id: SystemStats.shared.id.uuidString,
            details: SystemStats.Details(
                client: Client(
                    version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                    control: SystemStats.shared.control,
                    update: SystemStats.shared.update,
                ),
                system: SystemStats.System(
                    platform: "macOS",
                    vendor: "Apple",
                    model: SystemKit.shared.device.model.name,
                    modelID: SystemKit.shared.device.model.id,
                    os: SystemStats.OS(
                        name: SystemKit.shared.device.os?.name,
                        version: SystemKit.shared.device.os?.version.getFullVersion(),
                        build: SystemKit.shared.device.os?.build
                    ),
                    arch: SystemKit.shared.device.arch
                ),
                hardware: SystemStats.Hardware(
                    cpu: SystemKit.shared.device.info.cpu,
                    gpu: SystemKit.shared.device.info.gpu,
                    ram: SystemKit.shared.device.info.ram?.dimms,
                    disk: SystemKit.shared.device.info.disk
                )
            )
        )
        
        guard let body = try? JSONEncoder().encode(payload) else { return }
        request.httpBody = body
        
        self.authorizedData(for: request) { [weak self] data, response, _ in
            guard let self, let httpResponse = response as? HTTPURLResponse else { return }
            if httpResponse.statusCode == 200 {
                debug("Registered device: \(SystemStats.shared.id.uuidString)", log: self.log)
                self.fetchAccount()
            } else {
                let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                debug("Register remote failed (\(httpResponse.statusCode)): \(bodyString)", log: self.log)
            }
        }
    }
    
    private func fetchAccount() {
        guard let url = URL(string: "\(SystemStats.host)/v1/account") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(SystemStats.shared.auth.accessToken)", forHTTPHeaderField: "Authorization")
        
        struct AccountResponse: Codable {
            let plan: AccountPlan
        }
        
        self.authorizedData(for: request) { [weak self] data, response, _ in
            guard let self, let httpResponse = response as? HTTPURLResponse else { return }
            if httpResponse.statusCode == 200, let data,
               let account = try? JSONDecoder().decode(AccountResponse.self, from: data) {
                SystemStats.shared.plan = account.plan
                debug("Remote plan: \(account.plan.rawValue)", log: self.log)
                NotificationCenter.default.post(name: .remoteAuthenticated, object: nil)
            } else {
                let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                debug("Fetch account failed (\(httpResponse.statusCode)): \(bodyString)", log: self.log)
            }
        }
    }
    
    private func command(cmd: String, payload: Data?) {
        if cmd == "update" {
            guard self.update else { return }
            debug("received update command", log: self.log)
            self.triggerUpdate()
            self.mqtt.controlAck(cmd)
            return
        }
        
        guard self.control else { return }
        
        debug("received command '\(cmd)' with payload: \(String(data: payload ?? Data(), encoding: .utf8) ?? "")", log: self.log)
        
        switch cmd {
        case "disable":
            self.disableControl()
        case "sleep":
            self.sleep()
        case "restart-client":
            self.mqtt.controlAck(cmd)
            restartApp(self)
        case "volume":
            guard let payload else { return }
            let value = String(data: payload, encoding: .utf8)
            let step: Float32 = 0.0625
            switch value {
            case "up":
                if let current = self.getSystemVolume() {
                    if self.isSystemMuted() {
                        self.setSystemMute(false)
                    } else {
                        self.setSystemVolume(min(current + step, 1.0))
                    }
                }
            case "down":
                if let current = self.getSystemVolume() {
                    if self.isSystemMuted() {
                        self.setSystemMute(false)
                    } else {
                        self.setSystemVolume(max(current - step, 0.0))
                    }
                }
            case "mute":
                self.setSystemMute(true)
            case "unmute":
                self.setSystemMute(false)
            default: return
            }
        default: return
        }
        
        self.mqtt.controlAck(cmd)
    }
}

// MARK: - Audio helpers

extension SystemStats {
    func disableControl() {
        self.control = false
    }
    
    func triggerUpdate() {
        debug("received remote update command, checking for a new version...", log: self.log)
        NotificationCenter.default.post(name: .remoteUpdate, object: nil)
    }
    
    func sleep() {
        let minInterval: TimeInterval = 300
        let now = Date()
        self.cooldownLock.lock()
        if let last = self.lastSleepTime, now.timeIntervalSince(last) < minInterval {
            self.cooldownLock.unlock()
            debug("Sleep command ignored due to cooldown", log: self.log)
            return
        }
        self.lastSleepTime = now
        self.cooldownLock.unlock()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["sleepnow"]
        do {
            try process.run()
        } catch {
            self.cooldownLock.lock()
            self.lastSleepTime = nil
            self.cooldownLock.unlock()
            debug("Failed to invoke pmset sleepnow: \(error.localizedDescription)", log: self.log)
        }
    }
    
    private func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : nil
    }
    
    func isSystemMuted() -> Bool {
        guard let deviceID = self.getDefaultOutputDevice() else { return false }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var muteValue: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &size, &muteValue)
        return status == noErr && muteValue == 1
    }
    
    func setSystemMute(_ mute: Bool) {
        guard let deviceID = self.getDefaultOutputDevice() else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var muteValue: UInt32 = mute ? 1 : 0
        AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteValue)
    }
    
    func getSystemVolume() -> Float32? {
        guard let deviceID = self.getDefaultOutputDevice() else { return nil }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &size, &volume)
        return status == noErr ? volume : nil
    }
    
    func setSystemVolume(_ volume: Float32) {
        guard let deviceID = self.getDefaultOutputDevice() else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var vol = max(0.0, min(1.0, volume))
        AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
    }
}

// MARK: - Auth

public enum RemoteAuthError: Error {
    case unauthorized
}

public class RemoteAuth {
    private let credentialLock = NSRecursiveLock()
    private var credentialGeneration: UInt = 0
    fileprivate var generation: UInt {
        self.credentialLock.lock()
        defer { self.credentialLock.unlock() }
        return self.credentialGeneration
    }
    public var accessToken: String {
        get {
            self.credentialLock.lock()
            defer { self.credentialLock.unlock() }
            return RemoteKeychain.read("access_token") ?? ""
        }
        set {
            self.credentialLock.lock()
            defer { self.credentialLock.unlock() }
            RemoteKeychain.write(newValue, for: "access_token")
        }
    }
    private var refreshToken: String {
        get {
            self.credentialLock.lock()
            defer { self.credentialLock.unlock() }
            return RemoteKeychain.read("refresh_token") ?? ""
        }
        set {
            self.credentialLock.lock()
            defer { self.credentialLock.unlock() }
            RemoteKeychain.write(newValue, for: "refresh_token")
        }
    }
    private var clientID: String = "stats"
    
    private var deviceCode: String = ""
    private var userCode: String = ""
    private var interval: Int = 5
    private var repeater: Repeater?
    
    private var isRefreshing = false
    private var refreshCompletions: [(Result<String, Error>) -> Void] = []
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    
    private static let formAllowed: CharacterSet = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    
    private static func formBody(_ pairs: [(String, String)]) -> Data {
        let body = pairs.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }
    
    public init() {
        RemoteKeychain.migrateFromUserDefaultsIfNeeded()
    }
    
    deinit {
        self.session.invalidateAndCancel()
    }
    
    public func isAuthorized(completion: @escaping (Bool) -> Void) {
        self.authorize { result in
            if case .success = result { completion(true) } else { completion(false) }
        }
    }
    public func hasCredentials() -> Bool {
        self.credentialLock.lock()
        defer { self.credentialLock.unlock() }
        return !self.accessToken.isEmpty && !self.refreshToken.isEmpty
    }
    
    public func login(completion: @escaping (URL?) -> Void) {
        let generation = self.generation
        self.registerDevice { [weak self] device in
            guard let self, self.generation == generation else {
                completion(nil)
                return
            }
            guard let device else {
                completion(nil)
                return
            }
            completion(device.verification_uri_complete)
            
            self.deviceCode = device.device_code
            self.userCode = device.user_code
            self.interval = device.interval ?? 5
            
            self.repeater = Repeater(seconds: self.interval) { [weak self] in
                guard let self, self.generation == generation else { return }
                self.pollForToken(generation: generation) { [weak self] error in
                    guard let self, self.generation == generation else { return }
                    guard error == nil else {
                        print(error?.localizedDescription ?? "error pooling for token")
                        self.repeater?.pause()
                        self.repeater = nil
                        return
                    }
                }
            }
            self.repeater?.start()
        }
    }
    
    public func logout() {
        self.credentialLock.lock()
        self.credentialGeneration &+= 1
        self.accessToken = ""
        self.refreshToken = ""
        let completions = self.refreshCompletions
        self.refreshCompletions.removeAll()
        self.isRefreshing = false
        self.credentialLock.unlock()
        self.repeater?.pause()
        self.repeater = nil
        completions.forEach { $0(.failure(CancellationError())) }
    }
    
    fileprivate func authorize(rejectedToken: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        self.credentialLock.lock()
        let token = self.accessToken
        let refreshToken = self.refreshToken
        guard !token.isEmpty && !refreshToken.isEmpty else {
            self.credentialLock.unlock()
            completion(.failure(RemoteAuthError.unauthorized))
            return
        }
        // Another request may already have replaced the token rejected by the server.
        if rejectedToken != token && !self.isTokenExpired() {
            self.credentialLock.unlock()
            completion(.success(token))
            return
        }
        self.refreshCompletions.append(completion)
        guard !self.isRefreshing else {
            self.credentialLock.unlock()
            return
        }
        self.isRefreshing = true
        let generation = self.credentialGeneration
        self.credentialLock.unlock()
        
        var request = URLRequest(url: SystemStats.authHost.appendingPathComponent("token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = RemoteAuth.formBody([
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("device_id", SystemStats.shared.id.uuidString)
        ])
        
        self.session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            let result: Result<TokenResponse, Error>
            if let error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, http.statusCode == 400 || http.statusCode == 401 {
                result = .failure(RemoteAuthError.unauthorized)
            } else if let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let data, let token = try? JSONDecoder().decode(TokenResponse.self, from: data),
                      !token.access_token.isEmpty, !token.refresh_token.isEmpty {
                result = .success(token)
            } else {
                result = .failure(URLError(.badServerResponse))
            }
            self.completeRefresh(result, generation: generation)
        }.resume()
    }
    
    private func completeRefresh(_ result: Result<TokenResponse, Error>, generation: UInt) {
        self.credentialLock.lock()
        guard generation == self.credentialGeneration else {
            self.credentialLock.unlock()
            return
        }
        let authorization: Result<String, Error>
        switch result {
        case .success(let token):
            self.accessToken = token.access_token
            self.refreshToken = token.refresh_token
            authorization = .success(token.access_token)
        case .failure(let error):
            authorization = .failure(error)
        }
        let completions = self.refreshCompletions
        self.refreshCompletions.removeAll()
        self.isRefreshing = false
        self.credentialLock.unlock()
        completions.forEach { $0(authorization) }
    }
    
    private func registerDevice(completion: @escaping (DeviceResponse?) -> Void) {
        guard let url = URL(string: "\(SystemStats.authHost)/device") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = RemoteAuth.formBody([
            ("client_id", self.clientID),
            ("device_id", SystemStats.shared.id.uuidString)
        ])
        
        self.session.dataTask(with: request) { data, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data, let resp = try? JSONDecoder().decode(DeviceResponse.self, from: data) else {
                completion(nil)
                return
            }
            completion(resp)
        }.resume()
    }
    
    private func pollForToken(generation: UInt, completion: @escaping (Error?) -> Void) {
        guard let url = URL(string: "\(SystemStats.authHost)/token") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = RemoteAuth.formBody([
            ("client_id", self.clientID),
            ("device_code", self.deviceCode),
            ("grant_type", "urn:ietf:params:oauth:grant-type:device_code")
        ])
        
        self.session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                completion(nil)
                return
            }
            guard self.generation == generation else {
                completion(CancellationError())
                return
            }
            if let error = error {
                completion(error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                return
            }
            
            if httpResponse.statusCode == 200 {
                guard let data = data else {
                    completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data returned"]))
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(TokenResponse.self, from: data)
                    self.credentialLock.lock()
                    guard self.credentialGeneration == generation else {
                        self.credentialLock.unlock()
                        completion(CancellationError())
                        return
                    }
                    self.accessToken = result.access_token
                    self.refreshToken = result.refresh_token
                    self.credentialLock.unlock()
                    self.repeater?.pause()
                    self.repeater = nil
                    DispatchQueue.main.async {
                        guard self.generation == generation else { return }
                        NotificationCenter.default.post(name: .remoteLoginSuccess, object: nil)
                    }
                    completion(nil)
                } catch {
                    completion(error)
                }
            } else if httpResponse.statusCode == 400 {
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    completion(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Bad request"]))
                    return
                }
                
                if responseString.contains("authorization_pending") {
                    completion(nil)
                } else if responseString.contains("expired_token") {
                    completion(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Device code expired, please re-register"]))
                } else if responseString.contains("slow_down") {
                    self.interval += 5
                    self.repeater?.reset(seconds: self.interval)
                    self.repeater?.start()
                    completion(nil)
                } else {
                    completion(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: responseString]))
                }
            } else {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                completion(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to get token (\(httpResponse.statusCode)): \(errorMessage)"]))
            }
        }.resume()
    }
    
    private func isTokenExpired() -> Bool {
        let parts = self.accessToken.components(separatedBy: ".")
        guard parts.count == 3 else { return true }
        
        let payload = parts[1]
        var base64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        
        return Date().timeIntervalSince1970 >= exp
    }
}

// MARK: - MQTT

final class RemoteMetricBatch {
    private let queue: DispatchQueue
    private let publish: (Data) -> Void
    private var pending: [String: String] = [:]
    private var flush: DispatchWorkItem?
    
    init(queue: DispatchQueue, publish: @escaping (Data) -> Void) {
        self.queue = queue
        self.publish = publish
    }
    
    deinit {
        self.flush?.cancel()
    }
    
    func append(key: String, data: Data) {
        guard let value = String(data: data, encoding: .utf8) else { return }
        
        self.pending[key] = value
        guard self.flush == nil else { return }
        
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            
            let data = try? JSONEncoder().encode(self.pending)
            self.pending.removeAll(keepingCapacity: true)
            self.flush = nil
            if let data {
                self.publish(data)
            }
        }
        self.flush = work
        self.queue.asyncAfter(deadline: .now() + .milliseconds(500), execute: work)
    }
    
    func cancel() {
        self.flush?.cancel()
        self.flush = nil
        self.pending.removeAll()
    }
}

enum MQTTPacketType: UInt8 {
    case connect = 1
    case connack = 2
    case publish = 3
    case puback = 4
    case subscribe = 8
    case suback = 9
    case pingreq = 12
    case pingresp = 13
    case disconnect = 14
}

class MQTTManager: NSObject {
    public var registerCallback: (() -> Void)? = nil
    public var commandCallback: ((String, Data?) -> Void)? = nil
    public var unregisterHandler: (() -> Void)? = nil
    
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var isConnecting = false
    private var isDisconnected = false
    private var isReconnecting = false
    private var connectionGeneration: UInt = 0
    private var connectionToken: String?
    private var reconnectAttempts = 0
    private var maxReconnectDelay: TimeInterval = 60.0
    private var pingTimer: DispatchSourceTimer?
    private var reachability: Reachability = Reachability(start: true)
    private let log: NextLog
    private var packetIdentifier: UInt16 = 1
    
    private let stateQueue = DispatchQueue(label: "eu.exelban.Stats.Remote.MQTT")
    private static let stateQueueKey = DispatchSpecificKey<Void>()
    
    private lazy var metrics = RemoteMetricBatch(queue: self.stateQueue) { [weak self] data in
        guard let self, SystemStats.shared.monitoring && SystemStats.shared.isAuthorized else { return }
        
        self.publish(topic: "stats/\(SystemStats.shared.id.uuidString)/metrics", data: data)
    }
    
    override init() {
        self.log = NextLog.shared.copy(category: "Remote MQTT")
        
        super.init()
        
        self.stateQueue.setSpecific(key: MQTTManager.stateQueueKey, value: ())
        
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.underlyingQueue = self.stateQueue
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
        
        self.reachability.reachable = { [weak self] in
            if SystemStats.shared.auth.hasCredentials(),
               SystemStats.shared.monitoring || SystemStats.shared.control || SystemStats.shared.update {
                self?.connect()
            }
        }
        self.reachability.unreachable = { [weak self] in
            self?.disconnect()
        }
    }
    
    private func onStateQueue(_ block: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: MQTTManager.stateQueueKey) != nil {
            block()
        } else {
            self.stateQueue.async(execute: block)
        }
    }
    
    deinit {
        self.session?.invalidateAndCancel()
        self.session = nil
    }
    
    public func connect(rejectedToken: String? = nil) {
        self.onStateQueue {
            guard !self.isConnected && !self.isConnecting else { return }
            self.isDisconnected = false
            self.isConnecting = true
            let generation = self.connectionGeneration
            let authGeneration = SystemStats.shared.auth.generation
            
            SystemStats.shared.authorize(rejectedToken: rejectedToken) { [weak self = self] result in
                guard let self else { return }
                
                self.onStateQueue {
                    guard generation == self.connectionGeneration,
                          authGeneration == SystemStats.shared.auth.generation, !self.isDisconnected else { return }
                    switch result {
                    case .success(let token):
                        self.connectionToken = token
                        self.webSocket?.cancel(with: .normalClosure, reason: nil)
                        self.webSocket = self.session?.webSocketTask(with: SystemStats.brokerHost, protocols: ["mqtt"])
                        self.webSocket?.resume()
                        self.receiveMessage()
                        debug("MQTT WebSocket connecting...", log: self.log)
                    case .failure(let error):
                        self.isConnecting = false
                        if error is RemoteAuthError || error is CancellationError { return }
                        debug("Authorization failed, retrying connection...", log: self.log)
                        self.reconnect()
                    }
                }
            }
        }
    }
    
    public func disconnect() {
        self.onStateQueue {
            self.metrics.cancel()
            self.connectionGeneration &+= 1
            self.isDisconnected = true
            self.isConnecting = false
            self.isReconnecting = false
            self.reconnectAttempts = 0
            
            self.sendStatus(false)
            self.sendDisconnect()
            
            self.webSocket?.cancel(with: .normalClosure, reason: nil)
            self.webSocket = nil
            self.isConnected = false
            self.stopPingTimer()
            debug("MQTT disconnected gracefully", log: self.log)
        }
    }
    
    private func reconnect() {
        guard !self.isDisconnected && !self.isReconnecting else { return }
        
        self.isReconnecting = true
        
        let delays: [TimeInterval] = [1, 3, 5, 10, 20, 40]
        let delayIndex = min(self.reconnectAttempts, delays.count - 1)
        let delay = self.reconnectAttempts >= delays.count ? self.maxReconnectDelay : delays[delayIndex]
        
        debug("Waiting \(delay) seconds before next MQTT reconnection attempt...", log: self.log)
        let generation = self.connectionGeneration
        
        self.stateQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.connectionGeneration == generation else { return }
            
            self.isReconnecting = false
            
            guard !self.isDisconnected && !self.isConnected else {
                self.reconnectAttempts = 0
                return
            }
            
            self.reconnectAttempts += 1
            debug("Attempting MQTT reconnection #\(self.reconnectAttempts)", log: self.log)
            self.connect()
        }
    }
    
    public func sendStatus(_ value: Bool) {
        let status = value ? "online" : "offline"
        let topic = "stats/\(SystemStats.shared.id.uuidString)/status"
        if let payload = status.data(using: .utf8) {
            self.publish(topic: topic, data: payload)
        }
    }
    
    private func sendConnect() {
        guard let token = self.connectionToken else { return }
        let connectPacket = createConnectPacket(username: SystemStats.shared.id.uuidString, password: token)
        self.webSocket?.send(.data(connectPacket)) { error in
            if let error = error {
                print("Error sending MQTT CONNECT: \(error)")
            }
        }
    }
    
    private func sendDisconnect() {
        let disconnectPacket = Data([MQTTPacketType.disconnect.rawValue << 4, 0])
        self.webSocket?.send(.data(disconnectPacket)) { _ in }
    }
    
    private func sendPingRequest() {
        let pingPacket = Data([MQTTPacketType.pingreq.rawValue << 4, 0])
        self.webSocket?.send(.data(pingPacket)) { error in
            if let error = error {
                print("Error sending MQTT PINGREQ: \(error)")
            }
        }
    }
    
    public func controlAck(_ cmd: String) {
        let topic = "stats/\(SystemStats.shared.id.uuidString)/control-ack"
        if let payload = cmd.data(using: .utf8) {
            self.publish(topic: topic, data: payload)
        }
    }
    
    public func publish(topic: String, data: Data, retain: Bool = false) {
        self.onStateQueue {
            guard self.isConnected else { return }
            
            let publishPacket = self.createPublishPacket(topic: topic, payload: data, retain: retain)
            self.webSocket?.send(.data(publishPacket)) { error in
                if let error = error {
                    print("Error publishing MQTT message: \(error)")
                }
            }
        }
    }
    
    public func publishMetric(key: String, data: Data) {
        self.onStateQueue {
            guard self.isConnected && SystemStats.shared.monitoring && SystemStats.shared.isAuthorized else { return }
            
            self.metrics.append(key: key, data: data)
        }
    }
    
    public func discardMetrics() {
        self.onStateQueue {
            self.metrics.cancel()
        }
    }
    
    private func subscribe(to topic: String) {
        guard self.isConnected else { return }
        
        let subscribePacket = createSubscribePacket(topic: topic)
        self.webSocket?.send(.data(subscribePacket)) { error in
            if let error = error {
                print("Error subscribing to MQTT topic: \(error)")
            }
        }
    }
    
    private func createConnectPacket(username: String, password: String) -> Data {
        var packet = Data()
        
        let fixedHeaderByte = MQTTPacketType.connect.rawValue << 4
        
        var variableHeader = Data()
        variableHeader.append(contentsOf: encodeString("MQTT"))
        variableHeader.append(4)
        
        var connectFlags: UInt8 = 0x00
        connectFlags |= 0x80
        connectFlags |= 0x40
        variableHeader.append(connectFlags)
        variableHeader.append(contentsOf: [0x03, 0x84])
        
        var payload = Data()
        payload.append(contentsOf: encodeString("stats-\(username)"))
        payload.append(contentsOf: encodeString(username))
        payload.append(contentsOf: encodeString(password))
        
        let remainingLength = variableHeader.count + payload.count
        packet.append(fixedHeaderByte)
        packet.append(contentsOf: encodeRemainingLength(remainingLength))
        packet.append(variableHeader)
        packet.append(payload)
        
        return packet
    }
    
    private func createPublishPacket(topic: String, payload: Data, retain: Bool = false) -> Data {
        var packet = Data()
        
        let fixedHeaderByte = (MQTTPacketType.publish.rawValue << 4) | (retain ? 0x01 : 0x00)
        
        var variableHeader = Data()
        variableHeader.append(contentsOf: encodeString(topic))
        
        let remainingLength = variableHeader.count + payload.count
        
        packet.append(fixedHeaderByte)
        packet.append(contentsOf: encodeRemainingLength(remainingLength))
        packet.append(variableHeader)
        packet.append(payload)
        
        return packet
    }
    
    private func createSubscribePacket(topic: String) -> Data {
        var packet = Data()
        
        let fixedHeaderByte = (MQTTPacketType.subscribe.rawValue << 4) | 0x02
        
        var variableHeader = Data()
        
        let packetId = self.getNextPacketId()
        variableHeader.append(contentsOf: [UInt8(packetId >> 8), UInt8(packetId & 0xFF)])
        
        var payload = Data()
        payload.append(contentsOf: encodeString(topic))
        payload.append(0x00)
        
        let remainingLength = variableHeader.count + payload.count
        
        packet.append(fixedHeaderByte)
        packet.append(contentsOf: encodeRemainingLength(remainingLength))
        packet.append(variableHeader)
        packet.append(payload)
        
        return packet
    }
    
    private func encodeString(_ string: String) -> [UInt8] {
        let data = string.data(using: .utf8) ?? Data()
        let length = data.count
        return [UInt8(length >> 8), UInt8(length & 0xFF)] + Array(data)
    }
    
    private func encodeRemainingLength(_ length: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        var remainingLength = length
        
        repeat {
            var byte = UInt8(remainingLength % 128)
            remainingLength /= 128
            if remainingLength > 0 {
                byte |= 128
            }
            bytes.append(byte)
        } while remainingLength > 0
        
        return bytes
    }
    
    private func getNextPacketId() -> UInt16 {
        self.packetIdentifier &+= 1
        if self.packetIdentifier == 0 {
            self.packetIdentifier = 1
        }
        return self.packetIdentifier
    }
    
    private func handleMQTTPacket(_ data: Data) {
        guard data.count >= 2 else { return }
        
        let packetType = MQTTPacketType(rawValue: (data[0] >> 4) & 0x0F)
        
        switch packetType {
        case .connack:
            self.handleConnAck(data)
        case .pingresp:
            break
        case .suback:
            break
        case .publish:
            self.handlePublish(data)
        default:
            break
        }
    }
    
    private func handleConnAck(_ data: Data) {
        guard data.count >= 4 else { return }
        
        self.isConnecting = false
        
        let returnCode = data[3]
        if returnCode == 0 {
            self.isConnected = true
            self.isReconnecting = false
            self.reconnectAttempts = 0
            self.startPingTimer()
            self.subscribeToTopics()
            self.sendStatus(true)
            debug("MQTT connected successfully", log: self.log)
            DispatchQueue.main.async {
                self.registerCallback?()
            }
        } else {
            debug("MQTT connection failed with code: \(returnCode)", log: self.log)
        }
    }
    
    private func subscribeToTopics() {
        self.subscribe(to: "stats/\(SystemStats.shared.id.uuidString)/control/+")
        self.subscribe(to: "stats/\(SystemStats.shared.id.uuidString)/unregister")
    }
    
    private func receiveMessage() {
        guard let socket = self.webSocket else { return }
        socket.receive { [weak self] result in
            guard let self else { return }
            
            self.onStateQueue {
                guard socket === self.webSocket else { return }
                switch result {
                case .failure:
                    self.metrics.cancel()
                    self.isConnected = false
                    self.isConnecting = false
                    self.handleWebSocketError()
                case .success(let message):
                    switch message {
                    case .data(let data):
                        self.handleMQTTPacket(data)
                    case .string:
                        break
                    @unknown default:
                        break
                    }
                    self.receiveMessage()
                }
            }
        }
    }
    
    private func startPingTimer() {
        self.stopPingTimer()
        let timer = DispatchSource.makeTimerSource(queue: self.stateQueue)
        timer.schedule(deadline: .now() + 450, repeating: 450)
        timer.setEventHandler { [weak self] in
            self?.sendPingRequest()
        }
        timer.resume()
        self.pingTimer = timer
    }
    
    private func stopPingTimer() {
        self.pingTimer?.cancel()
        self.pingTimer = nil
    }
    
    private func handleWebSocketError() {
        if let response = self.webSocket?.response as? HTTPURLResponse, response.statusCode == 401 {
            self.connect(rejectedToken: self.connectionToken)
        } else {
            self.reconnect()
        }
    }
    
    private func handlePublish(_ data: Data) {
        var offset = 1
        while offset < data.count && data[offset] & 0x80 != 0 { offset += 1 }
        guard offset < data.count else { return }
        offset += 1
        
        guard data.count > offset + 1 else { return }
        let topicLength = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2
        
        guard data.count >= offset + topicLength else { return }
        let topicData = data.subdata(in: offset..<(offset + topicLength))
        guard let topic = String(data: topicData, encoding: .utf8) else { return }
        offset += topicLength
        
        let base = "stats/\(SystemStats.shared.id.uuidString)/"
        if topic == base + "unregister" {
            self.publish(topic: topic, data: Data(), retain: true)
            DispatchQueue.main.async {
                self.unregisterHandler?()
            }
            return
        }
        
        let controlPrefix = base + "control/"
        guard topic.hasPrefix(controlPrefix) else { return }
        let commandName = String(topic.dropFirst(controlPrefix.count))
        guard !commandName.isEmpty, !commandName.contains("/") else { return }
        let payload = data.subdata(in: offset..<data.count)
        DispatchQueue.main.async {
            self.commandCallback?(commandName, payload)
        }
    }
}

extension MQTTManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard webSocketTask === self.webSocket else { return }
        debug("MQTT WebSocket opened, sending CONNECT", log: self.log)
        self.sendConnect()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard webSocketTask === self.webSocket else { return }
        self.metrics.cancel()
        self.stopPingTimer()
        self.sendStatus(false)
        self.isConnected = false
        self.isConnecting = false
        debug("MQTT WebSocket closed", log: self.log)
        self.reconnect()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard task === self.webSocket else { return }
        self.metrics.cancel()
        if let error = error {
            if let response = task.response as? HTTPURLResponse {
                debug("MQTT WebSocket failed: \(error.localizedDescription), status: \(response.statusCode)", log: self.log)
            } else {
                debug("MQTT WebSocket failed: \(error.localizedDescription)", log: self.log)
            }
        }
        self.stopPingTimer()
        self.isConnected = false
        self.isConnecting = false
        if !self.isDisconnected {
            self.reconnect()
        }
    }
}

// MARK: - Keychain

enum RemoteKeychain {
    private static let service: String = (Bundle.main.bundleIdentifier ?? "eu.exelban.Stats") + ".remote"
    
    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func write(_ value: String, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        if value.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }
        
        let data = Data(value.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            for (k, v) in attributes { addQuery[k] = v }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
    
    static func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let migratedKey = "remote_tokens_migrated_to_keychain"
        if defaults.bool(forKey: migratedKey) { return }
        
        for key in ["access_token", "refresh_token"] {
            if let legacy = defaults.string(forKey: key), !legacy.isEmpty {
                write(legacy, for: key)
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(true, forKey: migratedKey)
    }
}
