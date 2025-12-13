import Foundation
import Kit

internal class RemoteReader: Reader<Remote_Metrics> {
    private var hostURL: String {
        Store.shared.string(key: "Remote_hostURL", defaultValue: "http://box:9090")
    }
    private var timeout: TimeInterval {
        TimeInterval(Store.shared.int(key: "Remote_timeout", defaultValue: 5))
    }

    public var lastError: String? = nil

    public override func setup() {
        self.defaultInterval = 2
    }

    public func updateHost() {
        // Force re-read of host URL from store on next read
    }

    public override func read() {
        let urlString = "\(self.hostURL)/cpu"
        guard let url = URL(string: urlString) else {
            self.lastError = "Invalid URL: \(urlString)"
            self.callback(nil)
            return
        }

        var request = URLRequest(url: url, timeoutInterval: self.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.lastError = error.localizedDescription
                DispatchQueue.main.async {
                    self.callback(nil)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.lastError = "Invalid response"
                DispatchQueue.main.async {
                    self.callback(nil)
                }
                return
            }

            guard httpResponse.statusCode == 200 else {
                self.lastError = "HTTP \(httpResponse.statusCode)"
                DispatchQueue.main.async {
                    self.callback(nil)
                }
                return
            }

            guard let data = data else {
                self.lastError = "No data received"
                DispatchQueue.main.async {
                    self.callback(nil)
                }
                return
            }

            do {
                let metrics = try JSONDecoder().decode(Remote_Metrics.self, from: data)
                self.lastError = nil
                DispatchQueue.main.async {
                    self.callback(metrics)
                }
            } catch {
                self.lastError = "Parse error: \(error.localizedDescription)"
                DispatchQueue.main.async {
                    self.callback(nil)
                }
            }
        }.resume()
    }
}
