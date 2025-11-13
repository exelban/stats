//
//  Remote.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 16/03/2025
//  Using Swift 6.0
//  Running on macOS 15.3
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import Cocoa
import CoreAudio

public protocol RemoteType {
    func remote() -> Data?
}

public class Remote {
    public static let shared = Remote()
    static public var host = URL(string: "https://api.system-stats.com")!
    static public var authHost = URL(string: "https://oauth.system-stats.com")!
    static public var brokerHost = URL(string: "wss://broker.system-stats.com:8084/mqtt")!
    
    public var monitoring: Bool {
        get { Store.shared.bool(key: "remote_monitoring", defaultValue: false) }
        set {
            Store.shared.set(key: "remote_monitoring", value: newValue)
            if newValue {
                self.start()
                self.registerDevice()
            } else if !self.control {
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
                self.registerDevice()
            } else if !self.monitoring {
                self.stop()
            }
        }
    }
    public let id: UUID
    public var isAuthorized: Bool = false
    public var auth: RemoteAuth = RemoteAuth()
    
    private let log: NextLog
    private var mqtt: MQTTManager = MQTTManager()
    private var isConnecting = false
    
    private var lastSleepTime: Date?
    private var lastRegisterTime: Date?
    
    struct Details: Codable {
        let client: Client
        let system: System
        let hardware: Hardware
    }

    struct Client: Codable {
        let version: String
        let control: Bool
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
        self.id = UUID(uuidString: Store.shared.string(key: "telemetry_id", defaultValue: UUID().uuidString)) ?? UUID()
        
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
        self.mqtt.disconnect()
        self.auth.logout()
        self.isAuthorized = false
        debug("Logout successfully from Stats Remote", log: self.log)
        NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized])
    }
    
    public func send(key: String, value: Any) {
        guard self.monitoring && self.isAuthorized, let v = value as? RemoteType, let data = v.remote() else { return }
        let topic = "stats/\(self.id.uuidString)/metrics/\(key)"
        self.mqtt.publish(topic: topic, data: data)
    }
    
    @objc private func successLogin() {
        self.isAuthorized = true
        NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized])
        self.mqtt.connect()
        debug("Login successfully on Stats Remote", log: self.log)
    }
    
    public func start() {
        self.auth.isAuthorized { [weak self] status in
            guard let self else { return }
            
            self.isAuthorized = status
            NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized])
            
            if status {
                self.mqtt.connect()
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
    
    private func registerDevice() {
        let oneHour: TimeInterval = 3600
        let now = Date()
        if let lastTime = self.lastRegisterTime, now.timeIntervalSince(lastTime) < oneHour {
            debug("Device registration skipped: cooldown period not met", log: self.log)
            return
        }
        self.lastRegisterTime = now
        
        guard let url = URL(string: "\(Remote.host)/remote/device") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Remote.shared.auth.accessToken)", forHTTPHeaderField: "Authorization")
        
        struct RegisterPayload: Codable {
            let id: String
            let details: Remote.Details
        }
        
        let payload = RegisterPayload(
            id: Remote.shared.id.uuidString,
            details: Remote.Details(
                client: Client(
                    version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                    control: Remote.shared.control
                ),
                system: Remote.System(
                    platform: "macOS",
                    vendor: "Apple",
                    model: SystemKit.shared.device.model.name,
                    modelID: SystemKit.shared.device.model.id,
                    os: Remote.OS(
                        name: SystemKit.shared.device.os?.name,
                        version: SystemKit.shared.device.os?.version.getFullVersion(),
                        build: SystemKit.shared.device.os?.build
                    ),
                    arch: SystemKit.shared.device.arch
                ),
                hardware: Remote.Hardware(
                    cpu: SystemKit.shared.device.info.cpu,
                    gpu: SystemKit.shared.device.info.gpu,
                    ram: SystemKit.shared.device.info.ram?.dimms,
                    disk: SystemKit.shared.device.info.disk
                )
            )
        )
        
        guard let body = try? JSONEncoder().encode(payload) else { return }
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let httpResponse = response as? HTTPURLResponse else { return }
            if httpResponse.statusCode == 200 {
                debug("Registered device: \(Remote.shared.id.uuidString)", log: self.log)
            } else {
                let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                debug("Register remote failed (\(httpResponse.statusCode)): \(bodyString)", log: self.log)
            }
        }.resume()
    }
    
    private func command(cmd: String, payload: Data?) {
        guard self.control else { return }
        
        debug("received command '\(cmd)' with payload: \(String(data: payload ?? Data(), encoding: .utf8) ?? "")", log: self.log)
        
        switch cmd {
        case "disable": self.disableControl()
        case "sleep": self.sleep()
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
            default: break
            }
        default: break
        }
    }
}

extension Remote {
    func disableControl() {
        self.control = false
    }
    
    func sleep() {
        let minInterval: TimeInterval = 300
        let now = Date()
        if let last = self.lastSleepTime, now.timeIntervalSince(last) < minInterval {
            debug("Sleep command ignored due to cooldown", log: self.log)
            return
        }
        self.lastSleepTime = now
        let process = Process()
        process.launchPath = "/usr/bin/pmset"
        process.arguments = ["sleepnow"]
        process.launch()
    }
    
    func isSystemMuted() -> Bool {
        var defaultOutputDeviceID = AudioDeviceID(0)
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
            &defaultOutputDeviceID
        )
        guard status == noErr else { return false }

        propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var muteValue: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        let muteStatus = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            &size,
            &muteValue
        )
        return muteStatus == noErr && muteValue == 1
    }
    
    func setSystemMute(_ mute: Bool) {
        var defaultOutputDeviceID = AudioDeviceID(0)
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
            &defaultOutputDeviceID
        )
        guard status == noErr else { return }

        propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var muteValue: UInt32 = mute ? 1 : 0
        AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &muteValue
        )
    }
    
    func getSystemVolume() -> Float32? {
        var defaultOutputDeviceID = AudioDeviceID(0)
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
            &defaultOutputDeviceID
        )
        guard status == noErr else { return nil }

        propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var volume: Float32 = 0
        size = UInt32(MemoryLayout<Float32>.size)
        let volStatus = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            &size,
            &volume
        )
        return volStatus == noErr ? volume : nil
    }

    func setSystemVolume(_ volume: Float32) {
        var defaultOutputDeviceID = AudioDeviceID(0)
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
            &defaultOutputDeviceID
        )
        guard status == noErr else { return }

        propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var vol = max(0.0, min(1.0, volume))
        AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &vol
        )
    }
}

public class RemoteAuth {
    public var accessToken: String {
        get { Store.shared.string(key: "access_token", defaultValue: "") }
        set { Store.shared.set(key: "access_token", value: newValue) }
    }
    private var refreshToken: String {
        get { Store.shared.string(key: "refresh_token", defaultValue: "") }
        set { Store.shared.set(key: "refresh_token", value: newValue) }
    }
    private var clientID: String = "stats"
    
    private var deviceCode: String = ""
    private var userCode: String = ""
    private var interval: Int = 5
    private var repeater: Repeater?
    
    private var lastValidationTime: Date?
    private var validationAttempts: Int = 0
    private let baseCooldown: TimeInterval = 2.0 // Start with 2 seconds
    private let maxCooldown: TimeInterval = 60.0 // Max 60 seconds
    
    public init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.successLogin), name: .remoteLoginSuccess, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .remoteLoginSuccess, object: nil)
    }
    
    public func isAuthorized(completion: @escaping (Bool) -> Void) {
        if !self.hasCredentials() {
            completion(false)
            return
        }
        
        if !self.accessToken.isEmpty && !self.isTokenExpired() {
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        
        self.validate(completion)
    }
    public func hasCredentials() -> Bool {
        return !self.accessToken.isEmpty && !self.refreshToken.isEmpty
    }
    
    public func login(completion: @escaping (URL?) -> Void) {
        self.registerDevice { device in
            guard let device else {
                completion(nil)
                return
            }
            completion(device.verification_uri_complete)
            
            self.deviceCode = device.device_code
            self.userCode = device.user_code
            self.interval = device.interval ?? 5
            
            self.repeater = Repeater(seconds: self.interval) {
                self.pollForToken { error in
                    guard error == nil else {
                        print(error?.localizedDescription ?? "error pooling for token")
                        self.repeater?.pause()
                        self.repeater = nil
                        return
                    }
                    if !self.accessToken.isEmpty {
                        self.repeater?.pause()
                        self.repeater = nil
                    }
                }
            }
            self.repeater?.start()
        }
    }
    
    public func logout() {
        self.accessToken = ""
        self.refreshToken = ""
    }
    
    private func validate(_ completion: @escaping (Bool) -> Void) {
        guard !self.accessToken.isEmpty && !self.refreshToken.isEmpty, let url = URL(string: "\(Remote.authHost)/me") else {
            completion(false)
            return
        }
        
        let now = Date()
        let dynamicCooldown = min(self.baseCooldown * pow(2.0, Double(self.validationAttempts)), self.maxCooldown)
        if let lastTime = self.lastValidationTime, now.timeIntervalSince(lastTime) < dynamicCooldown {
            let remainingTime = dynamicCooldown - now.timeIntervalSince(lastTime)
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                self.validate(completion)
            }
            return
        }
        
        self.lastValidationTime = now
        self.validationAttempts += 1
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self, error == nil, let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }
            
            if httpResponse.statusCode == 401 {
                self.refreshTokenFunc { ok in
                    if ok == true {
                        self.validationAttempts = 0
                        self.lastValidationTime = nil
                    }
                    completion(ok ?? false)
                }
            } else if httpResponse.statusCode == 200 {
                self.validationAttempts = 0
                self.lastValidationTime = nil
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    private func refreshTokenFunc(completion: @escaping (Bool?) -> Void) {
        guard let url = URL(string: "\(Remote.authHost)/token") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=refresh_token&refresh_token=\(self.refreshToken)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        request.httpBody = body?.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data, let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
                completion(nil)
                return
            }
            self.accessToken = token.access_token
            self.refreshToken = token.refresh_token
            completion(true)
        }.resume()
    }
    
    private func registerDevice(completion: @escaping (DeviceResponse?) -> Void) {
        guard let url = URL(string: "\(Remote.authHost)/device") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(self.clientID)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        request.httpBody = body?.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data, let resp = try? JSONDecoder().decode(DeviceResponse.self, from: data) else {
                completion(nil)
                return
            }
            completion(resp)
        }.resume()
    }
    
    private func pollForToken(completion: @escaping (Error?) -> Void) {
        guard let url = URL(string: "\(Remote.authHost)/token") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(self.clientID)&device_code=\(self.deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        request.httpBody = body?.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
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
                    NotificationCenter.default.post(name: .remoteLoginSuccess, object: nil, userInfo: [
                        "access_token": result.access_token,
                        "refresh_token": result.refresh_token
                    ])
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
                    DispatchQueue.global().asyncAfter(deadline: .now() + Double(self.interval)) {
                        completion(nil)
                    }
                } else {
                    completion(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: responseString]))
                }
            } else {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                completion(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to get token (\(httpResponse.statusCode)): \(errorMessage)"]))
            }
        }.resume()
    }
    
    @objc private func successLogin(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let accessToken = userInfo["access_token"] as? String,
            let refreshToken = userInfo["refresh_token"] as? String else { return }
        
        self.accessToken = accessToken
        self.refreshToken = refreshToken
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

struct MQTTMessage {
    let topic: String
    let payload: Data
    let qos: UInt8
    let retain: Bool
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
    private var isDisconnected = false
    private var isReconnecting = false
    private var reconnectAttempts = 0
    private var maxReconnectDelay: TimeInterval = 60.0
    private var pingTimer: Timer?
    private var reachability: Reachability = Reachability(start: true)
    private let log: NextLog
    private var packetIdentifier: UInt16 = 1
    
    override init() {
        self.log = NextLog.shared.copy(category: "Remote MQTT")
        
        super.init()
        
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        
        self.reachability.reachable = {
            if Remote.shared.isAuthorized {
                self.connect()
            }
        }
        self.reachability.unreachable = {
            if self.isConnected {
                self.disconnect()
            }
        }
    }
    
    public func connect() {
        guard !self.isConnected else { return }
        
        Remote.shared.auth.isAuthorized { [weak self] status in
            guard let self else { return }
            
            if status {
                self.webSocket = self.session?.webSocketTask(with: Remote.brokerHost, protocols: ["mqtt"])
                self.webSocket?.resume()
                self.receiveMessage()
                self.isDisconnected = false
                debug("MQTT WebSocket connecting...", log: self.log)
            } else {
                debug("Authorization failed, retrying connection...", log: self.log)
                self.reconnect()
            }
        }
    }
    
    public func disconnect() {
        if self.webSocket == nil && !self.isConnected { return }
        self.isDisconnected = true
        
        self.sendStatus(false)
        self.sendDisconnect()
        
        self.webSocket?.cancel(with: .normalClosure, reason: nil)
        self.webSocket = nil
        self.isConnected = false
        self.stopPingTimer()
        debug("MQTT disconnected gracefully", log: self.log)
    }
    
    private func reconnect() {
        guard !self.isDisconnected && !self.isReconnecting else { return }
        
        self.isReconnecting = true
        
        let delays: [TimeInterval] = [1, 3, 5, 10, 20, 40]
        let delayIndex = min(self.reconnectAttempts, delays.count - 1)
        let delay = self.reconnectAttempts >= delays.count ? self.maxReconnectDelay : delays[delayIndex]
        
        debug("Waiting \(delay) seconds before next MQTT reconnection attempt...", log: self.log)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            
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
        let topic = "stats/\(Remote.shared.id.uuidString)/status"
        let payload = status.data(using: .utf8)
        if let payload = payload {
            self.publish(topic: topic, data: payload)
        }
    }
    
    private func sendConnect() {
        let connectPacket = createConnectPacket(username: Remote.shared.id.uuidString, password: Remote.shared.auth.accessToken)
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
    
    public func publish(topic: String, data: Data) {
        guard self.isConnected else { return }
        
        let publishPacket = createPublishPacket(topic: topic, payload: data)
        self.webSocket?.send(.data(publishPacket)) { error in
            if let error = error {
                print("Error publishing MQTT message: \(error)")
            }
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
        
        // Fixed header - packet type only (remaining length will be added later)
        let fixedHeaderByte = MQTTPacketType.connect.rawValue << 4
        
        // Variable header
        var variableHeader = Data()
        variableHeader.append(contentsOf: encodeString("MQTT"))
        variableHeader.append(4)
        
        var connectFlags: UInt8 = 0x00 // Clean session
        connectFlags |= 0x80 // Username flag
        connectFlags |= 0x40 // Password flag
        variableHeader.append(connectFlags)
        variableHeader.append(contentsOf: [0x03, 0x84])
        
        // Payload
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
    
    private func createPublishPacket(topic: String, payload: Data) -> Data {
        var packet = Data()
        
        // Fixed header - packet type only
        let fixedHeaderByte = (MQTTPacketType.publish.rawValue << 4) | 0x00 // QoS 0
        
        // Variable header
        var variableHeader = Data()
        variableHeader.append(contentsOf: encodeString(topic))
        
        // Calculate remaining length
        let remainingLength = variableHeader.count + payload.count
        
        // Build final packet
        packet.append(fixedHeaderByte)
        packet.append(contentsOf: encodeRemainingLength(remainingLength))
        packet.append(variableHeader)
        packet.append(payload)
        
        return packet
    }
    
    private func createSubscribePacket(topic: String) -> Data {
        var packet = Data()
        
        // Fixed header - packet type only
        let fixedHeaderByte = (MQTTPacketType.subscribe.rawValue << 4) | 0x02
        
        // Variable header
        var variableHeader = Data()
        
        // Packet identifier
        let packetId = self.getNextPacketId()
        variableHeader.append(contentsOf: [UInt8(packetId >> 8), UInt8(packetId & 0xFF)])
        
        // Payload
        var payload = Data()
        payload.append(contentsOf: encodeString(topic))
        payload.append(0x00) // QoS 0
        
        // Calculate remaining length
        let remainingLength = variableHeader.count + payload.count
        
        // Build final packet
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
        self.packetIdentifier += 1
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
        
        let returnCode = data[3]
        if returnCode == 0 {
            self.isConnected = true
            self.isReconnecting = false
            self.reconnectAttempts = 0
            self.startPingTimer()
            self.subscribeToTopics()
            self.sendStatus(true)
            debug("MQTT connected successfully", log: self.log)
            self.registerCallback?()
        } else {
            debug("MQTT connection failed with code: \(returnCode)", log: self.log)
        }
    }
    
    private func subscribeToTopics() {
        self.subscribe(to: "stats/\(Remote.shared.id.uuidString)/control/+")
        self.subscribe(to: "stats/\(Remote.shared.id.uuidString)/unregister")
    }
    
    private func receiveMessage() {
        self.webSocket?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.isConnected = false
                self?.handleWebSocketError(error)
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleMQTTPacket(data)
                case .string:
                    break
                @unknown default:
                    break
                }
                self?.receiveMessage()
            }
        }
    }
    
    private func startPingTimer() {
        self.stopPingTimer()
        self.pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPingRequest()
        }
    }
    
    private func stopPingTimer() {
        self.pingTimer?.invalidate()
        self.pingTimer = nil
    }
    
    private func handleWebSocketError(_ error: Error) {
        if let urlError = error as? URLError, urlError.code.rawValue == 401 {
            Remote.shared.start()
        } else {
            self.reconnect()
        }
    }
    
    private func handlePublish(_ data: Data) {
        var offset = 1
        while data[offset] & 0x80 != 0 { offset += 1 }
        offset += 1
        
        guard data.count > offset + 1 else { return }
        let topicLength = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2
        
        guard data.count >= offset + topicLength else { return }
        let topicData = data.subdata(in: offset..<(offset + topicLength))
        let topic = String(data: topicData, encoding: .utf8) ?? "<invalid topic>"
        offset += topicLength
  
        if topic.hasSuffix("unregister") {
            self.unregisterHandler?()
            return
        }
        
        let prefix = "stats/\(Remote.shared.id.uuidString)/control/"
        let commandName = topic.hasPrefix(prefix) ? String(topic.dropFirst(prefix.count)) : topic
        let payload = data.subdata(in: offset..<data.count)
        self.commandCallback?(commandName, payload)
    }
}

extension MQTTManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        debug("MQTT WebSocket opened, sending CONNECT", log: self.log)
        self.sendConnect()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.isConnected = false
        self.stopPingTimer()
        self.sendStatus(false)
        debug("MQTT WebSocket closed", log: self.log)
        self.reconnect()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if let response = task.response as? HTTPURLResponse {
                let statusCode = response.statusCode
                let headers = response.allHeaderFields
                debug("MQTT WebSocket failed: \(error.localizedDescription), status: \(statusCode), headers: \(headers)", log: self.log)
            } else {
                debug("MQTT WebSocket failed: \(error.localizedDescription)", log: self.log)
            }
        }
    }
}
