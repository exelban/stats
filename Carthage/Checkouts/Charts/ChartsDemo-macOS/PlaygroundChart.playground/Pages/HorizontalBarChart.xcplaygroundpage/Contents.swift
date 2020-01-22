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

//: # Horizontal Bar Chart
import Cocoa
import Charts
import PlaygroundSupport


let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = HorizontalBarChartView(frame: r)
//: ### General
chartView.drawBarShadowEnabled = false
chartView.drawValueAboveBarEnabled = true
chartView.maxVisibleCount = 60
chartView.fitBars = true
chartView.gridBackgroundColor = NSUIColor.white
chartView.drawGridBackgroundEnabled = true
//: ### xAxis
let xAxis = chartView.xAxis
xAxis.labelPosition = .bothSided
xAxis.labelTextColor = #colorLiteral(red: 0, green: 0.9768045545, blue: 0, alpha: 1)
xAxis.labelFont = NSUIFont.systemFont(ofSize: CGFloat(12.0))
xAxis.drawAxisLineEnabled = true
xAxis.drawGridLinesEnabled = true
xAxis.granularity = 10.0
//: ### LeftAxis
let leftAxis = chartView.leftAxis
leftAxis.labelFont = NSUIFont.systemFont(ofSize: CGFloat(12.0))
leftAxis.labelTextColor = #colorLiteral(red: 0.01680417731, green: 0.1983509958, blue: 1, alpha: 1)
leftAxis.drawAxisLineEnabled = true
leftAxis.drawGridLinesEnabled = true
leftAxis.axisMinimum = 0.0
leftAxis.enabled = true
//: ### RightAxis
let rightAxis                  = chartView.rightAxis
rightAxis.labelFont            = NSUIFont.systemFont(ofSize: CGFloat(12.0))
rightAxis.labelTextColor        = #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
rightAxis.drawAxisLineEnabled  = true
rightAxis.drawGridLinesEnabled = false
rightAxis.axisMinimum          = 0.0
rightAxis.enabled              = true
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
let range = 50.0
let barWidth = 9.0
let spaceForBar = 10.0

var yVals = [BarChartDataEntry]()
for i in 0..<count
{
    let mult = range + 1.0
    let val = Double(arc4random_uniform(UInt32(mult)))
    yVals.append(BarChartDataEntry(x: Double(i) * spaceForBar, y: val))
}
//: ### BarChartDataSet
var set1 = BarChartDataSet()
set1 = BarChartDataSet(values: yVals, label: "DataSet")
set1.colors = ChartColorTemplates.vordiplom()

//: ### BarChartData
let data            = BarChartData(dataSets: [set1])
data.setValueFont(NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(10.0)))
data.barWidth       = barWidth
chartView.data = data

chartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView

/*:
 ****
 [Previous](@previous) | [Next](@next)
 */
