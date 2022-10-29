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

class RAM: XCTestCase {
    func testProcessReader_parseProcess() throws {
        var process = ProcessReader.parseProcess("3127  lldb-rpc-server  611M")
        XCTAssertEqual(process.pid, 3127)
        XCTAssertEqual(process.command, "lldb-rpc-server")
        XCTAssertEqual(process.usage, 611 * Double(1024 * 1024))
        
        process = ProcessReader.parseProcess("257   WindowServer     210M")
        XCTAssertEqual(process.pid, 257)
        XCTAssertEqual(process.command, "WindowServer")
        XCTAssertEqual(process.usage, 210 * Double(1024 * 1024))
        
        process = ProcessReader.parseProcess("7752  phpstorm         1819M")
        XCTAssertEqual(process.pid, 7752)
        XCTAssertEqual(process.command, "phpstorm")
        XCTAssertEqual(process.usage, 1819 * Double(1024 * 1024))
        
        process = ProcessReader.parseProcess("359   NotificationCent 62M")
        XCTAssertEqual(process.pid, 359)
        XCTAssertEqual(process.command, "NotificationCent")
        XCTAssertEqual(process.usage, 62 * Double(1024 * 1024))
        
        process = ProcessReader.parseProcess("623    SafariCloudHisto 1608K")
        XCTAssertEqual(process.pid, 623)
        XCTAssertEqual(process.command, "SafariCloudHisto")
        XCTAssertEqual(process.usage, (1608/1024) * Double(1024 * 1024))
        
        process = ProcessReader.parseProcess("174    WindowServer     1442M+ ")
        XCTAssertEqual(process.pid, 174)
        XCTAssertEqual(process.command, "WindowServer")
        XCTAssertEqual(process.usage, 1442 * Double(1024 * 1024))
        
        process = ProcessReader.parseProcess("329    Finder           488M+ ")
        XCTAssertEqual(process.pid, 329)
        XCTAssertEqual(process.command, "Finder")
        XCTAssertEqual(process.usage, 488 * Double(1024 * 1024))
        
        process = ProcessReader.parseProcess("7163* AutoCAD LT 2023  11G  ")
        XCTAssertEqual(process.pid, 7163)
        XCTAssertEqual(process.command, "AutoCAD LT 2023")
        XCTAssertEqual(process.usage, 11 * Double(1024 * 1024 * 1024))
    }
    
    func testKernelTask() throws {
        var process = ProcessReader.parseProcess("0      kernel_task      270M ")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.command, "kernel_task")
        XCTAssertEqual(process.usage, 270 * Double(1024 * 1024))
        
        process = ProcessReader.parseProcess("0     kernel_task      280M")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.command, "kernel_task")
        XCTAssertEqual(process.usage, 280 * Double(1024 * 1024))
    }
}
