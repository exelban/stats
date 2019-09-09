import XCTest
import FBSnapshotTestCase
@testable import Charts

class LineChartTests: FBSnapshotTestCase
{
    
    var chart: LineChartView!
    var dataSet: LineChartDataSet!
    
    override func setUp()
    {
        super.setUp()
        
        // Set to `true` to re-capture all snapshots
        self.recordMode = false
        
        // Sample data
        let values: [Double] = [8, 104, 81, 93, 52, 44, 97, 101, 75, 28,
            76, 25, 20, 13, 52, 44, 57, 23, 45, 91,
            99, 14, 84, 48, 40, 71, 106, 41, 45, 61]
        
        var entries: [ChartDataEntry] = Array()
        
        for (i, value) in values.enumerated()
        {
            entries.append(ChartDataEntry(x: Double(i), y: value, icon: UIImage(named: "icon", in: Bundle(for: self.classForCoder), compatibleWith: nil)))
        }
        
        dataSet = LineChartDataSet(entries: entries, label: "First unit test data")
        dataSet.drawIconsEnabled = false
        dataSet.iconsOffset = CGPoint(x: 0, y: 20.0)

        chart = LineChartView(frame: CGRect(x: 0, y: 0, width: 480, height: 350))
        chart.backgroundColor = NSUIColor.clear
        chart.leftAxis.axisMinimum = 0.0
        chart.rightAxis.axisMinimum = 0.0
        chart.data = LineChartData(dataSet: dataSet)
    }
    
    override func tearDown()
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDefaultValues()
    {
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testHidesValues()
    {
        dataSet.drawValuesEnabled = false
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testDoesntDrawCircles()
    {
        dataSet.drawCirclesEnabled = false
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testIsCubic()
    {
        dataSet.mode = LineChartDataSet.Mode.cubicBezier
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testDoesntDrawCircleHole()
    {
        dataSet.drawCircleHoleEnabled = false
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testDrawIcons()
    {
        dataSet.drawIconsEnabled = true
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
}
