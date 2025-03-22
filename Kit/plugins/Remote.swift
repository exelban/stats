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

public class Remote {
    public static let shared = Remote()
    static public var host = URL(string: "https://api.mac-stats.com")! // https://api.mac-stats.com http://localhost:8008
    
    public var state: Bool {
        get { Store.shared.bool(key: "remote_state", defaultValue: false) }
        set {
            Store.shared.set(key: "remote_state", value: newValue)
            if newValue {
                self.start()
            } else {
                self.stop()
            }
        }
    }
    public let id: UUID
    public var isAuthorized: Bool = false
    public var auth: RemoteAuth = RemoteAuth()
    
    private var ws: WebSocketManager = WebSocketManager()
    private var wsURL: URL?
    private var isConnecting = false
    
    public init() {
        self.id = UUID(uuidString: Store.shared.string(key: "telemetry_id", defaultValue: UUID().uuidString)) ?? UUID()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.state {
                self.start()
            } else {
                self.stop()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.successLogin), name: .remoteLoginSuccess, object: nil)
    }
    
    deinit {
        self.ws.disconnect()
        NotificationCenter.default.removeObserver(self, name: .remoteLoginSuccess, object: nil)
    }
    
    public func logout() {
        self.auth.logout()
        self.isAuthorized = false
        self.state = false
        self.ws.disconnect()
        NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized, "state": self.state])
    }
    
    public func send(key: String, value: Codable) {
        guard self.state && self.isAuthorized,
              let blobData = try? JSONEncoder().encode(value) else { return }
        self.ws.send(key: key, data: blobData)
    }
    
    @objc private func successLogin() {
        self.isAuthorized = true
        NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized, "state": self.state])
        
        if self.state {
            self.ws.connect()
        }
    }
    
    public func start() {
        self.auth.isAuthorized { [weak self] status in
            guard let self else { return }
            
            self.isAuthorized = status
            NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized, "state": self.state])
            
            if status {
                self.ws.connect()
            }
        }
    }
    
    private func stop() {
        self.ws.disconnect()
        NotificationCenter.default.post(name: .remoteState, object: nil, userInfo: ["auth": self.isAuthorized, "state": self.state])
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
    
    public init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.successLogin), name: .remoteLoginSuccess, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .remoteLoginSuccess, object: nil)
    }
    
    public func isAuthorized(completion: @escaping (Bool) -> Void) {
        self.validate(completion)
    }
    
    public func logout() {
        self.accessToken = ""
        self.refreshToken = ""
    }
    
    private func validate(_ completion: @escaping (Bool) -> Void) {
        guard !self.accessToken.isEmpty && !self.refreshToken.isEmpty, let url = URL(string: "\(Remote.host)/auth/me") else {
            completion(false)
            return
        }
        
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
                    completion(ok ?? false)
                }
            } else if httpResponse.statusCode == 200 {
                completion(true)
            }
        }.resume()
    }
    
    private func refreshTokenFunc(completion: @escaping (Bool?) -> Void) {
        guard let url = URL(string: "\(Remote.host)/auth/token") else {
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
    
    @objc private func successLogin(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let accessToken = userInfo["access_token"] as? String,
            let refreshToken = userInfo["refresh_token"] as? String else { return }
        
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

struct WebSocketMessage: Codable {
    let name: String
    let data: Data
    
    enum CodingKeys: String, CodingKey {
        case name
        case data
    }
}

class WebSocketManager: NSObject {
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var isDisconnected = false
    private let reconnectDelay: TimeInterval = 3.0
    private var pingTimer: Timer?
    private var reachability: Reachability = Reachability(start: true)
    
    override init() {
        super.init()
        
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        
        self.reachability.reachable = {
            if Remote.shared.state {
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
            guard status, let self else { return }
            
            var wsHost = Remote.host.absoluteString
            wsHost = wsHost.replacingOccurrences(of: "https", with: "wss").replacingOccurrences(of: "http", with: "ws")
            let url = URL(string: "\(wsHost)/remote?jwt=\(Remote.shared.auth.accessToken)&device_id=\(Remote.shared.id.uuidString)")!
            
            self.webSocket = self.session?.webSocketTask(with: url)
            self.webSocket?.resume()
            self.receiveMessage()
            self.isDisconnected = false
        }
    }
    
    public func disconnect() {
        self.isDisconnected = true
        self.webSocket?.cancel(with: .normalClosure, reason: nil)
        self.webSocket = nil
        self.isConnected = false
    }
    
    private func reconnect() {
        guard !self.isDisconnected else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + self.reconnectDelay) { [weak self] in
            self?.connect()
        }
    }
    
    private func sendDetails() {
        struct Details: Codable {
            let version: String
            let system: System
            let hardware: Hardware
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
        }
        
        struct Hardware: Codable {
            let cpu: cpu_s?
            let gpu: [gpu_s]?
            let ram: [dimm_s]?
        }
        
        let details = Details(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            system: System(
                platform: "macOS",
                vendor: "Apple",
                model: SystemKit.shared.device.model.name,
                modelID: SystemKit.shared.device.model.id,
                os: OS(
                    name: SystemKit.shared.device.os?.name,
                    version: SystemKit.shared.device.os?.version.getFullVersion(),
                    build: SystemKit.shared.device.os?.build
                )
            ),
            hardware: Hardware(
                cpu: SystemKit.shared.device.info.cpu,
                gpu: SystemKit.shared.device.info.gpu,
                ram: SystemKit.shared.device.info.ram?.dimms
            )
        )
        let jsonData = try? JSONEncoder().encode(details)
        self.send(key: "details", data: jsonData ?? Data())
    }
    
    public func send(key: String, data: Data) {
        if key != "details" && !key.contains("CPU@") && !key.contains("GPU@") && !key.contains("RAM@") && !key.contains("Network@") && !key.contains("Sensors@") {
            return
        }
        if !self.isConnected { return }
        let message = WebSocketMessage(name: key, data: data)
        guard let messageData = try? JSONEncoder().encode(message) else { return }
        self.webSocket?.send(.data(messageData)) { error in
            if let error = error {
                print("Error sending message: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        self.webSocket?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.isConnected = false
                self?.handleWebSocketError(error)
            case .success:
                self?.receiveMessage()
            }
        }
    }
    
    private func startPingTimer() {
        self.stopPingTimer()
        self.pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.ping()
        }
    }
    
    private func stopPingTimer() {
        self.pingTimer?.invalidate()
        self.pingTimer = nil
    }
    
    private func ping() {
        self.webSocket?.sendPing { [weak self] _ in
            self?.isConnected = false
            self?.reconnect()
        }
    }
    
    private func handleWebSocketError(_ error: Error) {
        if let urlError = error as? URLError, urlError.code.rawValue == 401 {
            Remote.shared.start()
        } else {
            self.reconnect()
        }
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.isConnected = true
        self.sendDetails()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.isConnected = false
        self.reconnect()
    }
}
