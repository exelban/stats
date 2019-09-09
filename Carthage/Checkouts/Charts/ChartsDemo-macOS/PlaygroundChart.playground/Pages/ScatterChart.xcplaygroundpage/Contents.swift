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

//: # Scatter Chart
import Cocoa
import Charts
import PlaygroundSupport

let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = ScatterChartView(frame: r)
//: ### General
chartView.drawGridBackgroundEnabled = false
chartView.setScaleEnabled ( true)
chartView.maxVisibleCount = 200
//: ### xAxis
let xAxis = chartView.xAxis
xAxis.labelFont = NSUIFont(name: "HelveticaNeue-Light", size: 10.0)!
xAxis.drawGridLinesEnabled = true
//: ### LeftAxis
let leftAxis = chartView.leftAxis
leftAxis.labelFont = NSUIFont(name: "HelveticaNeue-Light", size: 10.0)!
leftAxis.axisMinimum = 0.0
//: ### RightAxis
chartView.rightAxis.enabled = false
//: ### Legend
let legend = chartView.legend
legend.horizontalAlignment = .right
legend.verticalAlignment = .top
legend.orientation = .vertical
legend.drawInside = false
legend.font = NSUIFont(name: "HelveticaNeue-Light", size: 10.0)!
legend.xOffset = 5.0
//: ### Description
chartView.chartDescription?.enabled = false
//: ### ChartDataEntry
let count = 25
let range = 100.0

var yVals1 = [ChartDataEntry]()
var yVals2 = [ChartDataEntry]()
var yVals3 = [ChartDataEntry]()

for i in 0..<count
{
    var val = Double(arc4random_uniform(UInt32(range))) + 3
    yVals1.append(ChartDataEntry(x: Double(i), y: val))
    val = Double(arc4random_uniform(UInt32(range))) + 3
    yVals2.append(ChartDataEntry(x: Double(i) + 0.33, y: val))
    val = Double(arc4random_uniform(UInt32(range))) + 3
    yVals3.append(ChartDataEntry(x: Double(i) + 0.66, y: val))
}
//: ### ScatterChartDataSet
let set1 = ScatterChartDataSet(values: yVals1, label: "DS 1")
set1.setScatterShape(.square )
set1.colors =  ChartColorTemplates.liberty()
set1.scatterShapeSize = 10.0

let set2 = ScatterChartDataSet(values: yVals2, label: "DS 2")
set2.setScatterShape( .circle)
set2.scatterShapeHoleColor = NSUIColor.blue
set2.scatterShapeHoleRadius = 3.5
set2.colors = ChartColorTemplates.material()
set2.scatterShapeSize = 10.0

let set3 = ScatterChartDataSet(values: yVals3, label: "DS 3")
set3.setScatterShape(.triangle)
set3.colors = [NSUIColor.orange] //ChartColorTemplates.pastel()
set3.scatterShapeSize = 10.0

var dataSets = [ScatterChartDataSet]()
dataSets.append(set1)
dataSets.append(set2)
dataSets.append(set3)
//: ### ScatterChartData
let data = ScatterChartData(dataSets: dataSets)
data.setValueFont( NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(7.0)))
chartView.data = data

chartView.animate(xAxisDuration: 2.0, yAxisDuration: 2.0, easingOption: .easeInBounce)

/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView

/*:
 ****
 [Previous](@previous) | [Next](@next)
 */


