import XCTest
@testable import Charts

class ChartUtilsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDecimalWithNaN() {
        
        let number = Double.nan
        
        let actual = number.decimalPlaces
        let expected = 0
        
        XCTAssertEqual(expected, actual)
    }
    
    func testDecimalWithInfinite() {
        
        let number = Double.infinity
        
        let actual = number.decimalPlaces
        let expected = 0
        
        XCTAssertEqual(expected, actual)
    }
    
    func testDecimalWithZero() {
        
        let number = 0.0
        
        let actual = number.decimalPlaces
        let expected = 0
        
        XCTAssertEqual(expected, actual)
    }
    
    func testDecimalWithMaxValue() {
        
        let number = Double.greatestFiniteMagnitude
        
        let actual = number.decimalPlaces
        let expected = 0
        
        XCTAssertEqual(expected, actual)
    }
    
    func testDecimalWithMinValue() {
        
        let number = Double.leastNormalMagnitude
        
        let actual = number.decimalPlaces
        let expected = 310 // Don't think this is supposed to be this value maybe 0?
        
        XCTAssertEqual(expected, actual)
    }
    
    func testDecimalWithNormalValue() {
        
        let number = 13.123123
        
        let actual = number.decimalPlaces
        let expected = 1 // Don't think this is supposed to be this value maybe 6?
        
        XCTAssertEqual(expected, actual)
    }
}
