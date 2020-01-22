//
//  PlayGround
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  Copyright © 2017 thierry Hentic.
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
/*:
 ****
 [Menu](Menu)
 
 [Previous](@previous) | [Next](@next)
 ****
 */

//: # Stacked Bar
import Cocoa
import Charts
import PlaygroundSupport


let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = HorizontalBarChartView(frame: r)
//: ### General
chartView.drawBarShadowEnabled = false
chartView.drawValueAboveBarEnabled = false
chartView.maxVisibleCount = 60
chartView.fitBars = true
chartView.gridBackgroundColor = NSUIColor.white
chartView.drawGridBackgroundEnabled = true
//: ### xAxis
let xAxis = chartView.xAxis
xAxis.labelPosition = .bothSided
xAxis.labelTextColor = #colorLiteral(red: 0.01680417731, green: 0.1983509958, blue: 1, alpha: 1)
xAxis.labelFont = NSUIFont.systemFont(ofSize: CGFloat(12.0))
xAxis.drawAxisLineEnabled = true
xAxis.drawGridLinesEnabled = true
xAxis.granularity = 1.0
xAxis.avoidFirstLastClippingEnabled = false
//: ### LeftAxis
let leftAxis = chartView.leftAxis
leftAxis.labelFont = NSUIFont.systemFont(ofSize: CGFloat(12.0))
leftAxis.labelTextColor = #colorLiteral(red: 0, green: 0.9768045545, blue: 0, alpha: 1)
leftAxis.drawAxisLineEnabled = false
leftAxis.drawGridLinesEnabled = true
leftAxis.axisMinimum = 0.0
leftAxis.enabled = true
leftAxis.spaceTop    = 0.0
leftAxis.spaceBottom = 0.0
//: ### RightAxis
let rightAxis                  = chartView.rightAxis
rightAxis.labelFont            = NSUIFont.systemFont(ofSize: CGFloat(12.0))
rightAxis.labelTextColor        = #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
rightAxis.drawAxisLineEnabled  = true
rightAxis.drawGridLinesEnabled = true
rightAxis.axisMinimum          = 0.0
rightAxis.enabled              = true
rightAxis.spaceTop    = 0.5
rightAxis.spaceBottom = 0.5
//: ### Legend
let legend = chartView.legend
legend.horizontalAlignment = .left
legend.verticalAlignment = .bottom
legend.orientation = .horizontal
legend.drawInside = false
legend.form = .square
legend.formSize = 8.0
legend.font = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(11.0))!
legend.xEntrySpace = 4.0
//: ### Description
chartView.chartDescription?.text = "Horizontal Bar Chart"
//: ### BarChartDataEntry
let count = 12
let range =  100.0
let mult = 30.0

var yVals = [ChartDataEntry]()
for i in 0..<count
{

    let val1 = Double(arc4random_uniform(UInt32(mult)))
    let val2 = Double(arc4random_uniform(UInt32(mult)))
    let val3 = 100.0 - val1 - val2
    yVals.append(BarChartDataEntry(x: Double(i), yValues: [val1, val2, val3]))
}
//: ### BarChartDataSet
var set1 =  BarChartDataSet()
let formatter = NumberFormatter()
formatter.maximumFractionDigits = 1
formatter.negativeSuffix = " %"
formatter.positiveSuffix = " %"

set1 = BarChartDataSet(values: yVals, label: "Stack")
set1.colors = [ChartColorTemplates.material()[0], ChartColorTemplates.material()[1], ChartColorTemplates.material()[2]]
set1.valueFont = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(10.0))!
set1.valueFormatter = DefaultValueFormatter(formatter: formatter )
set1.valueTextColor = NSUIColor.white
set1.stackLabels = ["stack1", "stack2", "stack3"]

var dataSets = [BarChartDataSet]()
dataSets.append(set1)
//: ### BarChartData
let data = BarChartData()
data.addDataSet(dataSets[0] )
chartView.fitBars = true
chartView.data = data
/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView

/*:
 ****
 [Previous](@previous) | [Next](@next)
 */
