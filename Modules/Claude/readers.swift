//
//  readers.swift
//  Claude
//
//  Created by Stats Claude Module
//

import Cocoa
import Kit

internal class ClaudeUsageReader: Reader<Claude_Usage> {
    private var lastKnownUsage: Claude_Usage? = nil

    override init(_ module: ModuleType, popup: Bool = false, preview: Bool = false, history: Bool = false, callback: @escaping (Claude_Usage?) -> Void = {_ in }) {
        super.init(module, popup: popup, preview: preview, history: history, callback: callback)
        self.defaultInterval = 60
    }

    public override func read() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let token = Self.getAPIToken() else {
                // Token unavailable — keep last known value
                self?.callback(self?.lastKnownUsage)
                return
            }

            guard let headers = Self.probeRateLimit(token: token) else {
                // Probe failed — keep last known value
                self?.callback(self?.lastKnownUsage)
                return
            }

            var usage = Claude_Usage()
            usage.utilization5h = Double(headers["anthropic-ratelimit-unified-5h-utilization"] ?? "0") ?? 0
            usage.utilization7d = Double(headers["anthropic-ratelimit-unified-7d-utilization"] ?? "0") ?? 0
            usage.overageUtilization = Double(headers["anthropic-ratelimit-unified-overage-utilization"] ?? "0") ?? 0
            usage.fallbackPercentage = Double(headers["anthropic-ratelimit-unified-fallback-percentage"] ?? "0") ?? 0
            usage.status5h = headers["anthropic-ratelimit-unified-5h-status"] ?? "unknown"
            usage.status7d = headers["anthropic-ratelimit-unified-7d-status"] ?? "unknown"

            if let resetStr = headers["anthropic-ratelimit-unified-5h-reset"], let ts = Double(resetStr) {
                usage.reset5h = Date(timeIntervalSince1970: ts)
            }
            if let resetStr = headers["anthropic-ratelimit-unified-7d-reset"], let ts = Double(resetStr) {
                usage.reset7d = Date(timeIntervalSince1970: ts)
            }

            self?.lastKnownUsage = usage
            self?.callback(usage)
        }
    }

    // MARK: - API Token

    private static func getAPIToken() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        guard let jsonData = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }

        return token
    }

    // MARK: - Rate Limit Probe

    private static func probeRateLimit(token: String) -> [String: String]? {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "."]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let semaphore = DispatchSemaphore(value: 0)
        var resultHeaders: [String: String]?

        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                var headers: [String: String] = [:]
                for (key, value) in httpResponse.allHeaderFields {
                    if let k = key as? String, k.hasPrefix("anthropic-ratelimit") {
                        headers[k] = value as? String ?? "\(value)"
                    }
                }
                resultHeaders = headers
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        return resultHeaders
    }
}
