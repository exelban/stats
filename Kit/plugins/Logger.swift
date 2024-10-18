//
//  Logger.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 24/06/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Darwin
import Foundation

public enum LogLevel: String {
    case debug = "DBG"
    case info  = "INF"
    case error = "ERR"
}

public enum LogOption: Int {
    case timestamp
    case level
    case file
    case line
    
    public static func new() -> [LogOption] {
        return [timestamp, file, line, level]
    }
}

public enum LogWriter: Int {
    case stdout
    case stderr
    case file
}

public protocol Writer: TextOutputStream {
    var type: LogWriter { get }
}

public class NextLog {
    public static let shared = NextLog()
    
    private var writer: Writer = StderrOutputStream()
    private var category: String? = nil
    
    public init(writer: LogWriter = .stdout) {
        self.setWriter(writer)
    }
    
    public func copy(category: String? = nil) -> NextLog {
        let logger = NextLog()
        logger.writer = NextLog.shared.writer
        if let category = category {
            logger.category = category
        }
        return logger
    }
    
    public func log(level: LogLevel, options: [LogOption] = LogOption.new(), message: String, file: String = #file, line: UInt = #line) {
        self.writer.write(self.prefix(level, options, file, line) + " " + message + "\n")
    }
    
    public func setWriter(_ writer: LogWriter) {
        switch writer {
        case .stdout:
            self.writer = StdoutOutputStream()
        case .stderr:
            self.writer = StderrOutputStream()
        case .file:
            let fm = FileManager.default
            let fileURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("log.txt")
            
            if !fm.fileExists(atPath: fileURL.path) {
                try? Data("".utf8).write(to: fileURL)
            }
            
            do {
                let handle = try FileHandle(forWritingTo: fileURL)
                handle.seekToEndOfFile()
                handle.write(Data("----------------\n".utf8))
                self.writer = FileHandlerOutputStream(handle)
            } catch let err {
                print("error to init file handler: \(err)")
                self.writer = StdoutOutputStream()
            }
        }
    }
    
    private func prefix(_ level: LogLevel, _ options: [LogOption], _ file: String = #file, _ line: UInt = #line) -> String {
        var prefix = ""
        
        if options.contains(.timestamp) {
            self.space(&prefix, NextLog.timestampFormatter.string(from: Date()))
        }
        
        if options.contains(.file) {
            if let f = file.split(separator: "/").last {
                self.space(&prefix, String(f))
            }
            if options.contains(.line) {
                prefix += ":\(line)"
            }
        } else if options.contains(.line) {
            self.space(&prefix, "\(line)")
        }
        
        if options.contains(.level) {
            self.space(&prefix, level.rawValue)
        }
        
        if let category = self.category {
            self.space(&prefix, "[\(category)]")
        }
        
        return prefix
    }
    
    private func space(_ origin: inout String, _ str: String) {
        if origin.last != " " && !origin.isEmpty {
            origin += " "
        }
        origin += str
    }
}

extension NextLog {
    private static var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }
    
    private struct StdoutOutputStream: Writer {
        public let type: LogWriter = .stdout
        
        mutating func write(_ string: String) {
            fputs(string, stdout)
        }
    }
    
    private struct StderrOutputStream: Writer {
        public let type: LogWriter = .stderr
        
        mutating func write(_ string: String) {
            fputs(string, stderr)
        }
    }
    
    struct FileHandlerOutputStream: Writer {
        public let type: LogWriter = .file
        
        private let fileHandle: FileHandle
        private let encoding: String.Encoding
        
        init(_ fileHandle: FileHandle, encoding: String.Encoding = .utf8) {
            self.fileHandle = fileHandle
            self.encoding = encoding
        }
        
        mutating func write(_ string: String) {
            if let data = string.data(using: encoding) {
                self.fileHandle.write(data)
            }
        }
    }
}

public func debug(_ message: String, log: NextLog = NextLog.shared, file: String = #file, line: UInt = #line) {
    log.log(level: .debug, message: message, file: file, line: line)
}

public func info(_ message: String, log: NextLog = NextLog.shared, file: String = #file, line: UInt = #line) {
    log.log(level: .info, message: message, file: file, line: line)
}

public func error(_ message: String, log: NextLog = NextLog.shared, file: String = #file, line: UInt = #line) {
    log.log(level: .error, message: message, file: file, line: line)
}

public func error_msg(_ message: String, log: NextLog = NextLog.shared, file: String = #file, line: UInt = #line) {
    log.log(level: .error, message: message, file: file, line: line)
}
