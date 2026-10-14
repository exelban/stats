//
//  Disk.swift
//  Tests
//
//  Created by Serhiy Mytrovtsiy on 11/10/2026.
//  Using Swift 6.0.
//  Running on macOS 27.0.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest

@testable import Disk

class DiskTests: XCTestCase {
    func testDiskCounterValidation() {
        for value: Any? in [nil, "123", NSNumber(value: true), NSNumber(value: -1), NSNumber(value: 1.5), NSNumber(value: Double.nan), NSNumber(value: Double.infinity)] {
            let activity = ActivityReader.activity(value, previous: 0, elapsed: 1)
            XCTAssertNil(activity.bytes)
            XCTAssertEqual(activity.rate, 0)
        }
        XCTAssertEqual(ActivityReader.activity(NSNumber(value: UInt64.max), previous: nil, elapsed: 1).bytes, UInt64.max)
    }
    
    func testDiskRatesUseElapsedTimeAndAcceptZeroBaseline() {
        let first = ActivityReader.activity(NSNumber(value: 0), previous: nil, elapsed: 0)
        XCTAssertEqual(first.bytes, 0)
        let second = ActivityReader.activity(NSNumber(value: 5_000), previous: first.bytes, elapsed: 2.5)
        XCTAssertEqual(second.rate, 2_000)
        XCTAssertEqual(second.bytes, 5_000)
    }
    
    func testDiskIdleZeroIsValid() {
        let activity = ActivityReader.activity(NSNumber(value: 0), previous: 0, elapsed: 1)
        XCTAssertEqual(activity.rate, 0)
    }
    
    func testDiskCounterFailureRecoversIndependently() {
        let failed = ActivityReader.activity(nil, previous: 100, elapsed: 1)
        let write = ActivityReader.activity(NSNumber(value: 200), previous: 100, elapsed: 1)
        XCTAssertEqual(write.rate, 100)
        
        let recovering = ActivityReader.activity(NSNumber(value: 1_000), previous: failed.bytes, elapsed: 1)
        XCTAssertEqual(recovering.rate, 0)
        let recovered = ActivityReader.activity(NSNumber(value: 1_100), previous: recovering.bytes, elapsed: 1)
        XCTAssertEqual(recovered.rate, 100)
    }
    
    func testDiskCounterRegressionRebaselines() {
        let reset = ActivityReader.activity(NSNumber(value: 50), previous: 1_000, elapsed: 1)
        XCTAssertEqual(reset.rate, 0)
        let activity = ActivityReader.activity(NSNumber(value: 100), previous: reset.bytes, elapsed: 1)
        XCTAssertEqual(activity.rate, 50)
    }
    
    func testDiskInvalidElapsedTimeRebaselines() {
        for elapsed in [0, -1, Double.nan, Double.infinity] {
            let activity = ActivityReader.activity(NSNumber(value: 200), previous: 100, elapsed: elapsed)
            XCTAssertEqual(activity.bytes, 200)
            XCTAssertEqual(activity.rate, 0)
        }
    }
    
    func testDiskNewDriverStartsWithBaseline() {
        let activity = ActivityReader.activity(NSNumber(value: 10_000), previous: nil, elapsed: 1)
        XCTAssertEqual(activity.rate, 0)
    }
    
    func testDiskLargeCountersDoNotOverflow() {
        let read = ActivityReader.activity(NSNumber(value: UInt64.max), previous: UInt64.max - 100, elapsed: 0.000000001)
        let write = ActivityReader.activity(NSNumber(value: UInt64.max), previous: 0, elapsed: 0.000000001)
        XCTAssertEqual(read.rate, 100_000_000_000)
        XCTAssertEqual(write.rate, Int64.max)
    }
    
    func testDiskOldCachedDriveIgnoresRegistryHandle() throws {
        let data = try JSONEncoder().encode(drive(uuid: "volume", BSDName: "disk10s1"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["parent"] = 123
        let decoded = try JSONDecoder().decode(drive.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.uuid, "volume")
        XCTAssertEqual(decoded.BSDName, "disk10s1")
    }
}
