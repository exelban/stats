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
import Darwin
@testable import RAM

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
    
    func testMemoryBreakdownUsesAppWiredAndCompressedMemory() throws {
        var stats = vm_statistics64()
        stats.internal_page_count = 100
        stats.purgeable_count = 10
        stats.wire_count = 20
        stats.compressor_page_count = 5
        stats.external_page_count = 30
        stats.active_count = 40
        stats.inactive_count = 50
        stats.speculative_count = 40
        
        let pageSize = Double(4_096)
        let totalSize = Double(200) * pageSize
        let breakdown = UsageReader.memoryBreakdown(totalSize: totalSize, stats: stats, pageSize: pageSize)
        
        XCTAssertEqual(breakdown.app, Double(90) * pageSize)
        XCTAssertEqual(breakdown.wired, Double(20) * pageSize)
        XCTAssertEqual(breakdown.compressed, Double(5) * pageSize)
        XCTAssertEqual(breakdown.cache, Double(40) * pageSize)
        XCTAssertEqual(breakdown.used, Double(115) * pageSize)
        XCTAssertEqual(breakdown.free, Double(85) * pageSize)
    }
    
    func testBuildTopProcessListKeepsRealProcessNamesInIndividualMode() throws {
        let list = ProcessReader.buildTopProcessList(
            from: [
                RAMProcessSnapshot(pid: 101, name: "com.apple.WebKit.WebContent", usage: 800),
                RAMProcessSnapshot(pid: 202, name: "Telegram", usage: 400)
            ],
            combined: false,
            limit: 1,
            responsiblePidProvider: { $0 },
            appNameProvider: { _ in "Safari Web Content" }
        )
        
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].pid, 101)
        XCTAssertEqual(list[0].name, "com.apple.WebKit.WebContent")
        XCTAssertEqual(list[0].usage, 800)
    }
    
    func testBuildTopProcessListCombinesResponsibleProcesses() throws {
        let list = ProcessReader.buildTopProcessList(
            from: [
                RAMProcessSnapshot(pid: 11, name: "Codex Helper", usage: 500),
                RAMProcessSnapshot(pid: 12, name: "Codex Helper (Renderer)", usage: 300),
                RAMProcessSnapshot(pid: 21, name: "Telegram", usage: 600)
            ],
            combined: true,
            limit: 2,
            responsiblePidProvider: { pid in
                switch pid {
                case 11, 12: return 1
                case 21: return 2
                default: return pid
                }
            },
            appNameProvider: { pid in
                switch pid {
                case 1: return "Codex"
                case 2: return "Telegram"
                default: return nil
                }
            }
        )
        
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].pid, 1)
        XCTAssertEqual(list[0].name, "Codex")
        XCTAssertEqual(list[0].usage, 800)
        XCTAssertEqual(list[1].pid, 2)
        XCTAssertEqual(list[1].name, "Telegram")
        XCTAssertEqual(list[1].usage, 600)
    }
    
    func testBestProcessNamePrefersExecutableNameOverLocalizedAppName() throws {
        let name = ProcessReader.bestProcessName(
            pid: 5726,
            fallbackName: "Яндекс Музыка Helpe",
            executablePath: "/Applications/Яндекс Музыка.app/Contents/Frameworks/Яндекс Музыка Helper (Renderer).app/Contents/MacOS/Яндекс Музыка Helper (Renderer)",
            preferAppName: false,
            appNameProvider: { _ in "Яндекс Музыка" }
        )
        
        XCTAssertEqual(name, "Яндекс Музыка Helper (Renderer)")
    }
}
