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

//: # Line Chart
import Cocoa
import Charts
import PlaygroundSupport



let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = LineChartView(frame: r)
//: ### General
chartView.dragEnabled = true
chartView.setScaleEnabled ( true)
chartView.drawGridBackgroundEnabled = false
chartView.pinchZoomEnabled = true
chartView.backgroundColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
chartView.borderColor = NSUIColor.black
chartView.borderLineWidth = 1.0
chartView.drawBordersEnabled = true
//: ### xAxis
let xAxis = chartView.xAxis
xAxis.labelFont = NSUIFont.systemFont(ofSize: CGFloat(12.0))
xAxis.labelTextColor = #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)
xAxis.drawGridLinesEnabled = true
xAxis.drawAxisLineEnabled = true
xAxis.labelPosition = .bottom
xAxis.labelRotationAngle = 0
xAxis.axisMinimum = 0
//: ### LeftAxis
let leftAxis = chartView.leftAxis
leftAxis.labelTextColor = #colorLiteral(red: 0.215686274509804, green: 0.709803921568627, blue: 0.898039215686275, alpha: 1.0)
leftAxis.axisMaximum = 200.0
leftAxis.axisMinimum = 0.0
leftAxis.drawGridLinesEnabled = true
leftAxis.drawZeroLineEnabled = false
leftAxis.granularityEnabled = true
//: ### RightAxis
let rightAxis = chartView.rightAxis
rightAxis.labelTextColor = #colorLiteral(red: 1, green: 0.1474981606, blue: 0, alpha: 1)
rightAxis.axisMaximum = 900.0
rightAxis.axisMinimum = -200.0
rightAxis.drawGridLinesEnabled = false
rightAxis.granularityEnabled = false
//: ### Legend
let legend = chartView.legend
legend.font = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(12.0))!
legend.textColor = NSUIColor.black
legend.form = .square
legend.drawInside = false
legend.orientation = .horizontal
legend.verticalAlignment = .bottom
legend.horizontalAlignment = .left
//: ### Description
chartView.chartDescription?.enabled = false
//: ### ChartDataEntry
var yVals1 = [ChartDataEntry]()
var yVals2 = [ChartDataEntry]()
var yVals3 = [ChartDataEntry]()

let range = 30.0

for i in 0..<20 {
    let mult: Double = range / 2.0
    let val = Double(arc4random_uniform(UInt32(mult))) + 50
    yVals1.append(ChartDataEntry(x: Double(i), y: val))
}

for i in 0..<20 - 1 {
    let mult: Double = range
    let val = Double(arc4random_uniform(UInt32(mult))) + 450
    yVals2.append(ChartDataEntry(x: Double(i), y: val))
}

for i in 0..<20 {
    let mult: Double = range
    let val = Double(arc4random_uniform(UInt32(mult))) + 500
    yVals3.append(ChartDataEntry(x: Double(i), y: val))
}

var set1 = LineChartDataSet()
var set2 = LineChartDataSet()
var set3 = LineChartDataSet()

set1 = LineChartDataSet(values: yVals1, label: "DataSet 1")
set1.axisDependency = .left
set1.colors = [#colorLiteral(red: 0.215686274509804, green: 0.709803921568627, blue: 0.898039215686275, alpha: 1.0)]
set1.circleColors = [NSUIColor.white]
set1.lineWidth = 2.0
set1.circleRadius = 3.0
set1.fillAlpha = 65 / 255.0
set1.fillColor = #colorLiteral(red: 0.215686274509804, green: 0.709803921568627, blue: 0.898039215686275, alpha: 1.0)
set1.highlightColor = NSUIColor.blue
set1.highlightEnabled = true
set1.drawCircleHoleEnabled = false


set2 = LineChartDataSet(values: yVals2, label: "DataSet 2")
set2.axisDependency = .right
set2.colors = [NSUIColor.red]
set2.circleColors = [NSUIColor.white]
set2.lineWidth = 2.0
set2.circleRadius = 3.0
set2.fillAlpha = 65 / 255.0
set2.fillColor = NSUIColor.red
set2.highlightColor = NSUIColor.red
set2.highlightEnabled = true
set2.drawCircleHoleEnabled = false

set3 = LineChartDataSet(values: yVals3, label: "DataSet 3")
set3.axisDependency = .right
set3.colors = [NSUIColor.green]
set3.circleColors = [NSUIColor.white]
set3.lineWidth = 2.0
set3.circleRadius = 3.0
set3.fillAlpha = 65 / 255.0
set3.fillColor = NSUIColor.yellow.withAlphaComponent(200 / 255.0)
set3.highlightColor = NSUIColor.green
set3.highlightEnabled = true
set3.drawCircleHoleEnabled = false

var dataSets = [LineChartDataSet]()
dataSets.append(set1)
dataSets.append(set2)
dataSets.append(set3)
//: ### LineChartData
let data = LineChartData(dataSets: dataSets)
data.setValueTextColor(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1))
data.setValueFont(NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(9.0)))
chartView.data = data

chartView.data?.notifyDataChanged()
chartView.notifyDataSetChanged()
/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView


/*:
 ****
 [Previous](@previous) | [Next](@next)
 */
