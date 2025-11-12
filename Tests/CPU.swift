//
//  CPU.swift
//  Tests
//
//  Created to test CPU performance cores utilization calculation fix.
//  Testing issue #2785: Performance cores showing 75% instead of 100% when fully utilized.
//
//  Copyright © 2025. All rights reserved.
//

import XCTest
import CPU
import Kit

class CPU: XCTestCase {
    
    private func makeCore(id: Int32, type: coreType) -> core_s {
        let json = """
        {"id": \(id), "type": \(type.rawValue)}
        """
        guard let data = json.data(using: .utf8),
              let core = try? JSONDecoder().decode(core_s.self, from: data) else {
            fatalError("Failed to create core_s instance")
        }
        return core
    }
    
    func testPerformanceCoresShouldShow100Percent_Issue2785() throws {
        let usagePerCore: [Double] = [
            0.5, 0.5, 0.5, 0.5,
            1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
        ]
        
        let cores: [core_s] = [
            makeCore(id: 0, type: coreType.efficiency),
            makeCore(id: 1, type: coreType.efficiency),
            makeCore(id: 2, type: coreType.efficiency),
            makeCore(id: 3, type: coreType.efficiency),
            makeCore(id: 4, type: coreType.performance),
            makeCore(id: 5, type: coreType.performance),
            makeCore(id: 6, type: coreType.performance),
            makeCore(id: 7, type: coreType.performance),
            makeCore(id: 8, type: coreType.performance),
            makeCore(id: 9, type: coreType.performance),
            makeCore(id: 20, type: coreType.performance),
            makeCore(id: 21, type: coreType.performance)
        ]
        
        let usagePCores = calculatePerformanceCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNotNil(usagePCores, "Performance cores usage should be calculated")
        XCTAssertEqual(usagePCores!, 1.0, accuracy: 0.01,
                      "When all 8 performance cores are at 100%, should show 100%, not 75%")
        XCTAssertEqual(cores.filter({ $0.type == .performance }).count, 8, "Should have 8 performance cores")
    }
    
    func testCalculatePerformanceCoresUsage_AllCoresAt100Percent() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .efficiency),
            makeCore(id: 1, type: .performance),
            makeCore(id: 2, type: .performance),
            makeCore(id: 3, type: .performance)
        ]
        let usagePerCore: [Double] = [0.5, 1.0, 1.0, 1.0]
        
        let result = calculatePerformanceCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1.0, accuracy: 0.01, "All performance cores at 100% should return 100%")
    }
    
    func testCalculatePerformanceCoresUsage_MixedUsage() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .efficiency),
            makeCore(id: 1, type: .performance),
            makeCore(id: 2, type: .performance),
            makeCore(id: 3, type: .performance)
        ]
        let usagePerCore: [Double] = [0.5, 0.5, 0.75, 1.0]
        
        let result = calculatePerformanceCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNotNil(result)
        let expected = (0.5 + 0.75 + 1.0) / 3.0
        XCTAssertEqual(result!, expected, accuracy: 0.01, "Should calculate average of performance cores")
    }
    
    func testCalculatePerformanceCoresUsage_NoPerformanceCores() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .efficiency),
            makeCore(id: 1, type: .efficiency),
            makeCore(id: 2, type: .efficiency)
        ]
        let usagePerCore: [Double] = [0.5, 0.6, 0.7]
        
        let result = calculatePerformanceCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNil(result, "Should return nil when there are no performance cores")
    }
    
    func testCalculatePerformanceCoresUsage_CountMismatch() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .performance),
            makeCore(id: 1, type: .performance)
        ]
        let usagePerCore: [Double] = [1.0, 1.0, 1.0]
        
        let result = calculatePerformanceCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNil(result, "Should return nil when counts don't match")
    }
    
    func testCalculatePerformanceCoresUsage_EmptyArrays() throws {
        let cores: [core_s] = []
        let usagePerCore: [Double] = []
        
        let result = calculatePerformanceCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNil(result, "Should return nil for empty arrays")
    }
    
    func testCalculatePerformanceCoresUsage_PositionalMatching() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .efficiency),
            makeCore(id: 5, type: .performance),
            makeCore(id: 10, type: .performance),
            makeCore(id: 20, type: .performance)
        ]
        let usagePerCore: [Double] = [0.3, 0.8, 0.9, 1.0]
        
        let result = calculatePerformanceCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNotNil(result)
        let expected = (0.8 + 0.9 + 1.0) / 3.0
        XCTAssertEqual(result!, expected, accuracy: 0.01, "Should use positional matching, not ID-based")
    }
    
    func testCalculateEfficiencyCoresUsage_AllCoresAt50Percent() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .efficiency),
            makeCore(id: 1, type: .efficiency),
            makeCore(id: 2, type: .performance),
            makeCore(id: 3, type: .performance)
        ]
        let usagePerCore: [Double] = [0.5, 0.5, 1.0, 1.0]
        
        let result = calculateEfficiencyCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.5, accuracy: 0.01, "All efficiency cores at 50% should return 50%")
    }
    
    func testCalculateEfficiencyCoresUsage_MixedUsage() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .efficiency),
            makeCore(id: 1, type: .efficiency),
            makeCore(id: 2, type: .efficiency),
            makeCore(id: 3, type: .performance)
        ]
        let usagePerCore: [Double] = [0.3, 0.5, 0.7, 1.0]
        
        let result = calculateEfficiencyCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNotNil(result)
        let expected = (0.3 + 0.5 + 0.7) / 3.0
        XCTAssertEqual(result!, expected, accuracy: 0.01, "Should calculate average of efficiency cores")
    }
    
    func testCalculateEfficiencyCoresUsage_NoEfficiencyCores() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .performance),
            makeCore(id: 1, type: .performance),
            makeCore(id: 2, type: .performance)
        ]
        let usagePerCore: [Double] = [1.0, 1.0, 1.0]
        
        let result = calculateEfficiencyCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNil(result, "Should return nil when there are no efficiency cores")
    }
    
    func testCalculateEfficiencyCoresUsage_CountMismatch() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .efficiency),
            makeCore(id: 1, type: .efficiency)
        ]
        let usagePerCore: [Double] = [0.5, 0.6, 0.7]
        
        let result = calculateEfficiencyCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNil(result, "Should return nil when counts don't match")
    }
    
    func testCalculateEfficiencyCoresUsage_PositionalMatching() throws {
        let cores: [core_s] = [
            makeCore(id: 100, type: .efficiency),
            makeCore(id: 200, type: .efficiency),
            makeCore(id: 300, type: .performance)
        ]
        let usagePerCore: [Double] = [0.4, 0.6, 1.0]
        
        let result = calculateEfficiencyCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNotNil(result)
        let expected = (0.4 + 0.6) / 2.0
        XCTAssertEqual(result!, expected, accuracy: 0.01, "Should use positional matching, not ID-based")
    }
    
    func testCalculateEfficiencyCoresUsage_ZeroUsage() throws {
        let cores: [core_s] = [
            makeCore(id: 0, type: .efficiency),
            makeCore(id: 1, type: .efficiency),
            makeCore(id: 2, type: .performance)
        ]
        let usagePerCore: [Double] = [0.0, 0.0, 1.0]
        
        let result = calculateEfficiencyCoresUsage(cores: cores, usagePerCore: usagePerCore)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.0, accuracy: 0.01, "Should handle zero usage correctly")
    }
}
