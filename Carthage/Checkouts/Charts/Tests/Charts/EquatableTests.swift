//
//  EquatableTests.swift
//  Charts
//
//  Created by Jacob Christie on 2017-11-13.
//

import XCTest
@testable import Charts

class EquatableTests: XCTestCase {
    func testChartDataEntryEquality() {
        let image = UIImage()
        let data = NSObject()
        let entry1 = ChartDataEntry(x: 5, y: 3, icon: image, data: data)
        let entry2 = ChartDataEntry(x: 5, y: 3, icon: image, data: data)

        XCTAssertTrue(entry1 == entry2)
    }

    func testChartDataEntryInequality() {
        let image = UIImage()
        let data1 = NSObject()
        let data2 = NSObject()
        let entry1 = ChartDataEntry(x: 5, y: 3, icon: image, data: data1)
        let entry2 = ChartDataEntry(x: 5, y: 9, icon: image, data: data2)

        XCTAssertFalse(entry1 == entry2)
    }

    func testHighlightEquality() {
        let high1 = Highlight(x: 5, y: 3, xPx: 1, yPx: -1, dataSetIndex: 8, stackIndex: 8, axis: .right)
        let high2 = Highlight(x: 5, y: 3, xPx: 1, yPx: -1, dataSetIndex: 8, stackIndex: 8, axis: .right)

        XCTAssertTrue(high1 == high2)
    }

    func testHighlightInequality() {
        let high1 = Highlight(x: 5, y: 3, xPx: 1, yPx: -1, dataSetIndex: 8, stackIndex: 8, axis: .left)
        let high2 = Highlight(x: 5, y: 3, xPx: 1, yPx: -1, dataSetIndex: 8, stackIndex: 9, axis: .left)

        XCTAssertFalse(high1 == high2)
    }
}

