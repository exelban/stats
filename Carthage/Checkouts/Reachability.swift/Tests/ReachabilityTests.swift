//
//  ReachabilityTests.swift
//  ReachabilityTests
//
//  Created by Ashley Mills on 23/11/2015.
//  Copyright © 2015 Ashley Mills. All rights reserved.
//

import XCTest
@testable import Reachability

class ReachabilityTests: XCTestCase {
    
    func testValidHost() {
        let validHostName = "google.com"
        
        guard let reachability = try? Reachability(hostname: validHostName) else {
            return XCTFail("Unable to create reachability")
        }
        
        let expected = expectation(description: "Check valid host")
        reachability.whenReachable = { reachability in
            print("Pass: \(validHostName) is reachable - \(reachability)")

            // Only fulfill the expectation on host reachable
            expected.fulfill()
        }
        reachability.whenUnreachable = { reachability in
            print("\(validHostName) is initially unreachable - \(reachability)")
            // Expectation isn't fulfilled here, so wait will time out if this is the only closure called
        }
        
        do {
            try reachability.startNotifier()
        } catch {
            return XCTFail("Unable to start notifier")
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        reachability.stopNotifier()
    }

    func testInvalidHost() {
        // Testing with an invalid host will initially show as reachable, but then the callback
        // gets fired a second time reporting the host as unreachable

        let invalidHostName = "invalidhost"

        guard let reachability = try? Reachability(hostname: invalidHostName) else {
            return XCTFail("Unable to create reachability")
        }
        
        let expected = expectation(description: "Check invalid host")
        reachability.whenReachable = { reachability in
            print("\(invalidHostName) is initially reachable - \(reachability)")
        }
        
        reachability.whenUnreachable = { reachability in
            print("Pass: \(invalidHostName) is unreachable - \(reachability))")
            expected.fulfill()
        }
        
        do {
            try reachability.startNotifier()
        } catch {
            return XCTFail("Unable to start notifier")
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        reachability.stopNotifier()
    }

}
