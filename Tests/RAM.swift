//
//  RAM.swift
//  Tests
//
//  Created by Serhiy Mytrovtsiy on 16/04/2022.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
import RAM
import Kit

class RAM: XCTestCase {
    func testProcessReader_parseProcess() throws {
        var process = ProcessReader.parseProcess("3127  lldb-rpc-server  611M")
        XCTAssertEqual(process.pid, 3127)
        XCTAssertEqual(process.name, "lldb-rpc-server")
        XCTAssertEqual(process.usage, 611 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("257   WindowServer     210M")
        XCTAssertEqual(process.pid, 257)
        XCTAssertEqual(process.name, "WindowServer")
        XCTAssertEqual(process.usage, 210 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("7752  phpstorm         1819M")
        XCTAssertEqual(process.pid, 7752)
        XCTAssertEqual(process.name, "phpstorm")
        XCTAssertEqual(process.usage, 1819.0 / 1024 * 1000 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("359   NotificationCent 62M")
        XCTAssertEqual(process.pid, 359)
        XCTAssertEqual(process.name, "NotificationCent")
        XCTAssertEqual(process.usage, 62 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("623    SafariCloudHisto 1608K")
        XCTAssertEqual(process.pid, 623)
        XCTAssertEqual(process.name, "SafariCloudHisto")
        XCTAssertEqual(process.usage, (1608/1024) * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("174    WindowServer     1442M+ ")
        XCTAssertEqual(process.pid, 174)
        XCTAssertEqual(process.name, "WindowServer")
        XCTAssertEqual(process.usage, 1442 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("329    Finder           488M+ ")
        XCTAssertEqual(process.pid, 329)
        XCTAssertEqual(process.name, "Finder")
        XCTAssertEqual(process.usage, 488 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("7163* AutoCAD LT 2023  11G  ")
        XCTAssertEqual(process.pid, 7163)
        XCTAssertEqual(process.name, "AutoCAD LT 2023")
        XCTAssertEqual(process.usage, 11 * Double(1024 * 1000 * 1000))
    }
    
    func testKernelTask() throws {
        var process = ProcessReader.parseProcess("0      kernel_task      270M ")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.name, "kernel_task")
        XCTAssertEqual(process.usage, 270 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("0     kernel_task      280M")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.name, "kernel_task")
        XCTAssertEqual(process.usage, 280 * Double(1000 * 1000))
    }
    
    func testSizes() throws {
        var process = ProcessReader.parseProcess("0  com.apple.Virtua 8463M")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.name, "com.apple.Virtua")
        XCTAssertEqual(process.usage, 8463.0 / 1024 * 1000 * 1000 * 1000)
        
        process = ProcessReader.parseProcess("0  Safari           658M")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.name, "Safari")
        XCTAssertEqual(process.usage, 658 * Double(1000 * 1000))
    }
}

final class ReaderLifecycleTests: XCTestCase {
    private final class ProbeReader: Reader<Int> {
        private let queue = DispatchQueue(label: "io.serhiy.Stats.Tests.ProbeReader")
        private var _readCount: Int = 0
        var onRead: ((Int) -> Void)?

        var readCount: Int {
            self.queue.sync { self._readCount }
        }

        override func read() {
            self.queue.sync {
                self._readCount += 1
                let current = self._readCount
                self.onRead?(current)
            }
            self.callback(self.readCount)
        }
    }

    func testPopupReaderForcesReadWhenReopened() {
        let reader = ProbeReader(.CPU, popup: true)
        reader.unlock()

        let firstRead = expectation(description: "first read")
        reader.onRead = { count in
            if count == 1 {
                firstRead.fulfill()
            }
        }

        reader.start()
        wait(for: [firstRead], timeout: 5)

        reader.pause()

        let secondRead = expectation(description: "second read after reopen")
        reader.onRead = { count in
            if count == 2 {
                secondRead.fulfill()
            }
        }

        reader.start()
        wait(for: [secondRead], timeout: 5)

        reader.stop()
    }

    func testReplayEmitsCachedValueWithoutNewRead() {
        var callbackValues: [Int] = []
        let reader = ProbeReader(.CPU) { value in
            if let value {
                callbackValues.append(value)
            }
        }
        let firstRead = expectation(description: "initial read")
        reader.onRead = { count in
            if count == 1 {
                firstRead.fulfill()
            }
        }

        reader.start()
        wait(for: [firstRead], timeout: 5)

        XCTAssertEqual(reader.readCount, 1)
        let callbacksBeforeReplay = callbackValues.count

        reader.replay()

        XCTAssertEqual(reader.readCount, 1)
        XCTAssertEqual(callbackValues.count, callbacksBeforeReplay + 1)
        XCTAssertEqual(callbackValues.last, 1)

        reader.stop()
    }
}
