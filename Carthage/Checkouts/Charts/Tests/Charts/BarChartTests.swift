import XCTest
import FBSnapshotTestCase
@testable import Charts

class BarChartTests: FBSnapshotTestCase
{
    override func setUp()
    {
        super.setUp()
        
        // Set to `true` to re-capture all snapshots
        self.recordMode = false
    }
    
    override func tearDown()
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    //MARK: Prepare
    func setupCustomValuesDataEntries(values: [Double]) -> [ChartDataEntry]
    {
        var entries: [ChartDataEntry] = Array()
        for (i, value) in values.enumerated()
        {
            entries.append(BarChartDataEntry(x: Double(i), y: value, icon: UIImage(named: "icon", in: Bundle(for: self.classForCoder), compatibleWith: nil)))
        }
        return entries
    }

    func setupDefaultValuesDataEntries() -> [ChartDataEntry]
    {
        let values: [Double] = [8, 104, -81, 93, 52, -44, 97, 101, -75, 28,
                                -76, 25, 20, -13, 52, 44, -57, 23, 45, -91,
                                99, 14, -84, 48, 40, -71, 106, 41, -45, 61]
        return setupCustomValuesDataEntries(values: values)
    }

    func setupPositiveValuesDataEntries() -> [ChartDataEntry]
    {
        let values: [Double] = [8, 104, 81, 93, 52, 44, 97, 101, 75, 28,
                                76, 25, 20, 13, 52, 44, 57, 23, 45, 91,
                                99, 14, 84, 48, 40, 71, 106, 41, 45, 61]
        return setupCustomValuesDataEntries(values: values)
    }

    func setupNegativeValuesDataEntries() -> [ChartDataEntry]
    {
        let values: [Double] = [-8, -104, -81, -93, -52, -44, -97, -101, -75, -28,
                                -76, -25, -20, -13, -52, -44, -57, -23, -45, -91,
                                -99, -14, -84, -48, -40, -71, -106, -41, -45, -61]
        return setupCustomValuesDataEntries(values: values)
    }

    func setupZeroValuesDataEntries() -> [ChartDataEntry]
    {
        let values = [Double](repeating: 0.0, count: 30)
        return setupCustomValuesDataEntries(values: values)
    }

    func setupStackedValuesDataEntries() -> [ChartDataEntry]
    {
        var entries: [ChartDataEntry] = Array()
        entries.append(BarChartDataEntry(x: 0, yValues: [28, 50, 60, 30, 42], icon: UIImage(named: "icon")))
        entries.append(BarChartDataEntry(x: 1, yValues: [-20, -36, -52, -40, -15], icon: UIImage(named: "icon")))
        entries.append(BarChartDataEntry(x: 2, yValues: [10, 30, 40, 90, 72], icon: UIImage(named: "icon")))
        entries.append(BarChartDataEntry(x: 3, yValues: [-40, -50, -30, -60, -20], icon: UIImage(named: "icon")))
        entries.append(BarChartDataEntry(x: 4, yValues: [10, 40, 60, 45, 62], icon: UIImage(named: "icon")))
        return entries
    }

    func setupDefaultStackedDataSet(chartDataEntries: [ChartDataEntry]) -> BarChartDataSet
    {
        let dataSet = BarChartDataSet(entries: chartDataEntries, label: "Stacked bar chart unit test data")
        dataSet.drawIconsEnabled = false
        dataSet.iconsOffset = CGPoint(x: 0, y: -10.0)
        dataSet.colors = Array(arrayLiteral:NSUIColor(red: 46/255.0, green: 204/255.0, blue: 113/255.0, alpha: 1.0),
                               NSUIColor(red: 241/255.0, green: 196/255.0, blue: 15/255.0, alpha: 1.0),
                               NSUIColor(red: 231/255.0, green: 76/255.0, blue: 60/255.0, alpha: 1.0),
                               NSUIColor(red: 52/255.0, green: 152/255.0, blue: 219/255.0, alpha: 1.0)
        )
        return dataSet
    }

    func setupDefaultDataSet(chartDataEntries: [ChartDataEntry]) -> BarChartDataSet
    {
        let dataSet = BarChartDataSet(entries: chartDataEntries, label: "Bar chart unit test data")
        dataSet.drawIconsEnabled = false
        dataSet.iconsOffset = CGPoint(x: 0, y: -10.0)
        return dataSet
    }

    func setupDefaultChart(dataSets: [BarChartDataSet]) -> BarChartView
    {
        let data = BarChartData(dataSets: dataSets)
        data.barWidth = 0.85
        
        let chart = BarChartView(frame: CGRect(x: 0, y: 0, width: 480, height: 350))
        chart.backgroundColor = NSUIColor.clear
        chart.data = data
        return chart
    }
    
    //MARK: Start Test
    func testDefaultValues()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)

    }

    func testDefaultBarDataSetLabels()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = BarChartDataSet(entries: dataEntries)
        dataSet.drawIconsEnabled = false
        let chart = setupDefaultChart(dataSets: [dataSet])
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testZeroValues()
    {
        let dataEntries = setupZeroValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testPositiveValues()
    {
        let dataEntries = setupPositiveValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testPositiveValuesWithCustomAxisMaximum()
    {
        let dataEntries = setupPositiveValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.axisMaximum = 50
        chart.clipValuesToContentEnabled = true
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testPositiveValuesWithCustomAxisMaximum2()
    {
        let dataEntries = setupPositiveValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.axisMaximum = -10
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testPositiveValuesWithCustomAxisMinimum()
    {
        let dataEntries = setupPositiveValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.axisMinimum = 50
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testPositiveValuesWithCustomAxisMinimum2()
    {
        let dataEntries = setupPositiveValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.axisMinimum = 110
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testPositiveValuesWithCustomAxisMaximumAndCustomAxisMaximum()
    {
        let dataEntries = setupPositiveValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        //If min is greater than max, then min and max will be exchanged.
        chart.leftAxis.axisMaximum = 200
        chart.leftAxis.axisMinimum = -10
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testNegativeValues()
    {
        let dataEntries = setupNegativeValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testNegativeValuesWithCustomAxisMaximum()
    {
        let dataEntries = setupNegativeValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.axisMaximum = 10
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testNegativeValuesWithCustomAxisMaximum2()
    {
        let dataEntries = setupNegativeValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.axisMaximum = -150
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }


    func testNegativeValuesWithCustomAxisMinimum()
    {
        let dataEntries = setupNegativeValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.axisMinimum = -200
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testNegativeValuesWithCustomAxisMinimum2()
    {
        let dataEntries = setupNegativeValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.axisMinimum = 10
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testNegativeValuesWithCustomAxisMaximumAndCustomAxisMaximum()
    {
        let dataEntries = setupNegativeValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        //If min is greater than max, then min and max will be exchanged.
        chart.leftAxis.axisMaximum = 10
        chart.leftAxis.axisMinimum = -200
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testHidesValues()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        dataSet.drawValuesEnabled = false
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testNotDrawValueAboveBars()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.drawValueAboveBarEnabled = false
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testStackedDrawValues()
    {
        let dataEntries = setupStackedValuesDataEntries()
        let dataSet = setupDefaultStackedDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testStackedNotDrawValues()
    {
        let dataEntries = setupStackedValuesDataEntries()
        let dataSet = setupDefaultStackedDataSet(chartDataEntries: dataEntries)
        dataSet.drawValuesEnabled = false
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testStackedNotDrawValuesAboveBars()
    {
        let dataEntries = setupStackedValuesDataEntries()
        let dataSet = setupDefaultStackedDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.drawValueAboveBarEnabled = false
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testHideLeftAxis()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.enabled = false
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testHideRightAxis()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.rightAxis.enabled = false
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testInvertedLeftAxis()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.inverted = true
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testInvertedLeftAxisWithNegativeValues()
    {
        let dataEntries = setupNegativeValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.inverted = true
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testInvertedLeftAxisWithPositiveValues()
    {
        let dataEntries = setupPositiveValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.inverted = true
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testInvertedRightAxis()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        dataSet.axisDependency = .right
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.rightAxis.inverted = true
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testInvertedRightAxisWithNegativeValues()
    {
        let dataEntries = setupNegativeValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        dataSet.axisDependency = .right
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.rightAxis.inverted = true
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }

    func testInvertedRightAxisWithPositiveValues()
    {
        let dataEntries = setupPositiveValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        dataSet.axisDependency = .right
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.rightAxis.inverted = true
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testHideHorizontalGridlines()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.leftAxis.drawGridLinesEnabled = false
        chart.rightAxis.drawGridLinesEnabled = false
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testHideVerticalGridlines()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        chart.xAxis.drawGridLinesEnabled = false
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
    
    func testDrawIcons()
    {
        let dataEntries = setupDefaultValuesDataEntries()
        let dataSet = setupDefaultDataSet(chartDataEntries: dataEntries)
        let chart = setupDefaultChart(dataSets: [dataSet])
        dataSet.drawIconsEnabled = true
        chart.notifyDataSetChanged()
        ChartsSnapshotVerifyView(chart, identifier: Snapshot.identifier(UIScreen.main.bounds.size), overallTolerance: Snapshot.tolerance)
    }
}
