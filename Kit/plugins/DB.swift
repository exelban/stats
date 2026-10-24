//
//  DB.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 03/02/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

public struct HistoryStatistic: Codable {
    public var average: Double
    public var minimum: Double
    public var maximum: Double
    public var count: Int
    public var duration: TimeInterval
    
    public init(average: Double, minimum: Double, maximum: Double, count: Int, duration: TimeInterval) {
        self.average = average
        self.minimum = minimum
        self.maximum = maximum
        self.count = count
        self.duration = duration
    }
    
    var isValid: Bool {
        self.average.isFinite && self.minimum.isFinite && self.maximum.isFinite && self.minimum <= self.maximum &&
        self.count >= 1 && self.duration.isFinite && self.duration > 0
    }
    
    mutating func merge(_ value: HistoryStatistic) {
        let duration = self.duration + value.duration
        self.average = self.average * (self.duration / duration) + value.average * (value.duration / duration)
        self.minimum = min(self.minimum, value.minimum)
        self.maximum = max(self.maximum, value.maximum)
        self.count += value.count
        self.duration = duration
    }
}

public struct HistoryBucket: Codable {
    public let timestamp: Date
    public var recordedAt: Date
    public var snapshot: Data
    public var values: [String: HistoryStatistic]
    
    public init(timestamp: Date, recordedAt: Date, snapshot: Data, values: [String: HistoryStatistic]) {
        self.timestamp = timestamp
        self.recordedAt = recordedAt
        self.snapshot = snapshot
        self.values = values
    }
    
    var isValid: Bool {
        self.timestamp.timeIntervalSince1970.isFinite && self.recordedAt.timeIntervalSince1970.isFinite &&
        !self.snapshot.isEmpty && self.values.values.allSatisfy{ $0.isValid }
    }
    
    mutating func merge(_ bucket: HistoryBucket) {
        for (path, value) in bucket.values {
            if self.values[path] != nil {
                self.values[path]?.merge(value)
            } else {
                self.values[path] = value
            }
        }
        if bucket.recordedAt >= self.recordedAt {
            self.recordedAt = bucket.recordedAt
            self.snapshot = bucket.snapshot
        }
    }
}

public class DB {
    public static let shared = DB()
    
    private var lldb: LLDB? = nil
    private let queue = DispatchQueue(label: "eu.exelban.db")
    private let ttl: Int = 60*60
    
    private let historyQueue = DispatchQueue(label: "eu.exelban.db.history")
    private let historyRetention: TimeInterval = 24*60*60
    private var historyTimer: DispatchSourceTimer?
    // Only unsaved samples are kept in memory; stored history is merged when reading or saving.
    private var historyBuckets: [String: [Date: HistoryBucket]] = [:]
    private var lastHistoryCleanup: Date?
    
    public var _writeTS: [String: Date] = [:]
    public var writeTS: [String: Date] {
        get { self.queue.sync { self._writeTS } }
        set { self.queue.sync { self._writeTS = newValue } }
    }
    
    private var _values: [String: Codable] = [:]
    public var values: [String: Codable] {
        get { self.queue.sync { self._values } }
        set { self.queue.sync { self._values = newValue } }
    }
    
    init() {
        let fileManager = FileManager.default
        let supportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Stats")
        let tmpPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Stats")
        
        for path in [supportPath, tmpPath] {
            try? fileManager.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            if let lldb = LLDB(path.appendingPathComponent("lldb").path) {
                self.lldb = lldb
                self.startHistoryTimer()
                return
            }
        }
        
        print("ERROR INITIALIZE DB")
    }
    
    deinit {
        self.historyTimer?.cancel()
        self.lldb?.close()
    }
    
    public func setup<T: Codable>(_ type: T.Type, _ key: String) {
        self.clean(key)
        if let raw = self.lldb?.findOne(key), let value = try? JSONDecoder().decode(type, from: Data(raw.utf8)) {
            self.queue.sync { self._values[key] = value }
        }
    }
    
    public func insert(key: String, value: Codable, force: Bool = false) {
        self.queue.sync { self._values[key] = value }
        guard let blobData = try? JSONEncoder().encode(value), let str = String(data: blobData, encoding: .utf8) else { return }
        
        let now = Date()
        let shouldWrite: Bool = self.queue.sync {
            if !force, let ts = self._writeTS[key], (now.timeIntervalSince1970-ts.timeIntervalSince1970) < 30 {
                return false
            }
            self._writeTS[key] = now
            return true
        }
        guard shouldWrite else { return }
        
        self.lldb?.insert(key, value: str)
    }
    
    public func findOne<T: Decodable>(_ dynamicType: T.Type, key: String) -> T? {
        return self.values[key] as? T
    }
    
    public func recordHistory<T: Encodable>(key: String, value: T, at: Date = Date(), duration: TimeInterval = 1) {
        guard !key.isEmpty, at.timeIntervalSince1970.isFinite, duration.isFinite, duration > 0 else { return }
        guard at.addingTimeInterval(60) > at else { return }
        guard let snapshot = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: snapshot, options: .fragmentsAllowed) else { return }
        var values: [String: Double] = [:]
        self.historyValues(object, path: "", values: &values)
        
        self.historyQueue.async {
            let cutoff = Date().addingTimeInterval(-self.historyRetention)
            var start = max(at.addingTimeInterval(-min(duration, self.historyRetention)), cutoff)
            guard start < at else { return }
            
            while start < at {
                let timestamp = self.historyMinute(start)
                let end = min(timestamp.addingTimeInterval(60), at)
                let duration = end.timeIntervalSince(start)
                
                let statistics = values.mapValues{ HistoryStatistic(average: $0, minimum: $0, maximum: $0, count: 1, duration: duration) }
                let bucket = HistoryBucket(timestamp: timestamp, recordedAt: at, snapshot: snapshot, values: statistics)
                if self.historyBuckets[key]?[timestamp] != nil {
                    self.historyBuckets[key]?[timestamp]?.merge(bucket)
                } else {
                    self.historyBuckets[key, default: [:]][timestamp] = bucket
                }
                start = end
            }
        }
    }
    
    public func loadHistory(key: String, from: Date, to: Date, completion: @escaping ([HistoryBucket]) -> Void) {
        self.historyQueue.async {
            guard from.timeIntervalSince1970.isFinite, to.timeIntervalSince1970.isFinite, from < to else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let start = self.historyMinute(max(from, Date().addingTimeInterval(-self.historyRetention)))
            let end = self.historyMinute(to).addingTimeInterval(to == self.historyMinute(to) ? 0 : 60)
            guard start < end else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            var values = self.load(key: key, from: start, to: end) ?? [:]
            for (timestamp, bucket) in self.historyBuckets[key] ?? [:] where timestamp >= start && timestamp < end {
                if values[timestamp] != nil {
                    values[timestamp]?.merge(bucket)
                } else {
                    values[timestamp] = bucket
                }
            }
            let result = values.values.sorted{ $0.timestamp < $1.timestamp }
            DispatchQueue.main.async { completion(result) }
        }
    }
    
    public func flush() {
        self.historyQueue.sync {
            self.persistHistory()
        }
    }
    
    private func historyMinute(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 60) * 60)
    }
    
    private func historyValues(_ object: Any, path: String, values: inout [String: Double]) {
        if let number = object as? NSNumber {
            if CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite {
                values[path] = number.doubleValue
            }
        } else if let object = object as? [String: Any] {
            for (key, value) in object {
                self.historyValues(value, path: "\(path)/field:\(self.historyPath(key))", values: &values)
            }
        } else if let array = object as? [Any] {
            let identifiers = array.map{ ($0 as? [String: Any]).flatMap{ self.historyIdentity($0) } }
            var counts: [String: Int] = [:]
            identifiers.compactMap{ $0 }.forEach{ counts[$0, default: 0] += 1 }
            
            for (index, value) in array.enumerated() {
                if value is [String: Any] {
                    // Ambiguous objects remain in the snapshot without combining unrelated measurements.
                    guard let identifier = identifiers[index], counts[identifier] == 1 else { continue }
                    self.historyValues(value, path: "\(path)/item:\(self.historyPath(identifier))", values: &values)
                } else {
                    self.historyValues(value, path: "\(path)/index:\(index)", values: &values)
                }
            }
        }
    }
    
    private func historyPath(_ value: String) -> String {
        // Segment types distinguish fields, array indices and device identities.
        value.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
    }
    
    private func historyIdentity(_ object: [String: Any]) -> String? {
        for key in ["id", "uuid", "BSDName"] {
            if let value = object[key] as? String, !value.isEmpty {
                return "\(key):\(value)"
            }
        }
        if let ioClass = object["IOClass"] as? String, let model = object["model"] as? String, !ioClass.isEmpty, !model.isEmpty {
            return "IOClass:\(ioClass.utf8.count):\(ioClass)\(model)"
        }
        return nil
    }
    
    private func persistHistory() {
        self.cleanupHistory()
        var values: [String: [HistoryBucket]] = [:]
        
        for (key, list) in self.historyBuckets {
            for (timestamp, value) in list {
                guard let stored = self.load(key: key, from: timestamp, to: timestamp.addingTimeInterval(60)),
                      stored.keys.allSatisfy({ $0 == timestamp }) else { continue }
                var bucket = value
                if var previous = stored[timestamp] {
                    previous.merge(value)
                    bucket = previous
                }
                guard bucket.isValid else { continue }
                values[key, default: []].append(bucket)
            }
        }
        
        guard !values.isEmpty, self.save(values) else { return }
        for (key, list) in values {
            for bucket in list {
                self.historyBuckets[key]?.removeValue(forKey: bucket.timestamp)
            }
            if self.historyBuckets[key]?.isEmpty == true {
                self.historyBuckets.removeValue(forKey: key)
            }
        }
    }
    
    private func cleanupHistory() {
        let now = Date()
        let cutoff = self.historyMinute(now.addingTimeInterval(-self.historyRetention))
        for key in Array(self.historyBuckets.keys) {
            self.historyBuckets[key] = self.historyBuckets[key]?.filter{ $0.key >= cutoff }
            if self.historyBuckets[key]?.isEmpty == true {
                self.historyBuckets.removeValue(forKey: key)
            }
        }
        
        if let lastCleanup = self.lastHistoryCleanup, now >= lastCleanup, now.timeIntervalSince(lastCleanup) < 15*60 {
            return
        }
        if self.prune(before: cutoff) {
            self.lastHistoryCleanup = now
        }
    }
    
    private func startHistoryTimer() {
        let timer = DispatchSource.makeTimerSource(queue: self.historyQueue)
        timer.schedule(deadline: .now() + 60, repeating: 60, leeway: .seconds(5))
        timer.setEventHandler { [weak self] in
            self?.persistHistory()
        }
        timer.resume()
        self.historyTimer = timer
        self.historyQueue.async { [weak self] in
            self?.cleanupHistory()
        }
    }
    
    private func clean(_ key: String) {
        guard let keys = self.lldb?.keys(key) as? [String] else { return }
        let maxLiveTS = Date().currentTimeSeconds() - self.ttl
        var toDeleteKeys: [String] = []
        
        keys.forEach { (key: String) in
            if let ts = key.split(separator: "@").last, let ts = Int(ts), ts < maxLiveTS {
                toDeleteKeys.append(key)
            }
        }
        
        self.lldb?.deleteMany(toDeleteKeys)
    }
    
    private func historyPrefix(_ key: String) -> String {
        "history@v2@\(Data(key.utf8).base64EncodedString())@"
    }
    
    private func historyTimestamp(_ date: Date) -> String? {
        guard let seconds = Int64(exactly: date.timeIntervalSince1970.rounded(.towardZero)) else { return nil }
        let timestamp = UInt64(bitPattern: seconds) ^ (UInt64(1) << 63)
        return String(format: "%020llu", timestamp)
    }
    
    private func load(key: String, from: Date, to: Date) -> [Date: HistoryBucket]? {
        let prefix = self.historyPrefix(key)
        guard let start = self.historyTimestamp(from), let end = self.historyTimestamp(to) else { return nil }
        guard let values = self.lldb?.findRange(
            prefix,
            from: "\(prefix)\(start)",
            to: "\(prefix)\(end)"
        ) else { return nil }
        var buckets: [Date: HistoryBucket] = [:]
        
        for (key, value) in values {
            guard let bucket = try? JSONDecoder().decode(HistoryBucket.self, from: Data(value.utf8)),
                  bucket.isValid,
                  let timestamp = self.historyTimestamp(bucket.timestamp),
                  key == "\(prefix)\(timestamp)" else {
                return nil
            }
            buckets[bucket.timestamp] = bucket
        }
        
        return buckets
    }
    
    private func save(_ buckets: [String: [HistoryBucket]]) -> Bool {
        var values: [String: String] = [:]
        for (key, list) in buckets {
            let prefix = self.historyPrefix(key)
            for bucket in list {
                guard bucket.isValid,
                      let timestamp = self.historyTimestamp(bucket.timestamp),
                      let data = try? JSONEncoder().encode(bucket),
                      let value = String(data: data, encoding: .utf8) else { return false }
                values["\(prefix)\(timestamp)"] = value
            }
        }
        guard !values.isEmpty else { return true }
        return self.lldb?.insertMany(values) ?? false
    }
    
    private func prune(before: Date) -> Bool {
        guard let timestamp = self.historyTimestamp(before) else { return false }
        return self.lldb?.delete(before: "history@", timestamp: timestamp) ?? false
    }
}
