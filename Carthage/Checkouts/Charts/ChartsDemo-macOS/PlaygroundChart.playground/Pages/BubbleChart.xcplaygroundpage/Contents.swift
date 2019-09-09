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
 
 [Previous](@previous)
 ****
 */

//: # Bubble Chart
import Cocoa
import Charts
import PlaygroundSupport

let ITEM_COUNT  = 20

let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = BubbleChartView(frame: r)
//: ### General
chartView.drawGridBackgroundEnabled = true
//: ### xAxis
let xAxis                           = chartView.xAxis
xAxis.labelPosition                 = .bothSided
xAxis.axisMinimum                   = 0.0
xAxis.granularity                   = 1.0
//: ### LeftAxis
let leftAxis                        = chartView.leftAxis
leftAxis.drawGridLinesEnabled       = true
leftAxis.axisMinimum                = 40.0
//: ### RightAxis
let rightAxis                       = chartView.rightAxis
rightAxis.drawGridLinesEnabled      = true
rightAxis.axisMinimum               = 40.0
//: ### Legend
let legend                          = chartView.legend
legend.wordWrapEnabled              = true
legend.horizontalAlignment          = .center
legend.verticalAlignment            = .bottom
legend.orientation                  = .horizontal
legend.drawInside                   = false
//: ### Description
chartView.chartDescription?.enabled = false
//: ### BubbleChartDataEntry
var entries = [BubbleChartDataEntry]()
for index in 0..<ITEM_COUNT
{
    let y = Double(arc4random_uniform(100)) + 50.0
    let size = (y - 50) / 25.0
    entries.append(BubbleChartDataEntry(x: Double(index) + 0.5, y: y, size: CGFloat(size)))
}
//: ### BubbleChartDataSet
let set = BubbleChartDataSet(values: entries, label: "Bubble DataSet")
set.colors = ChartColorTemplates.vordiplom()
set.valueTextColor = NSUIColor.black
set.valueFont = NSUIFont.systemFont(ofSize: CGFloat(10.0))
set.drawValuesEnabled = true
set.normalizeSizeEnabled = false
//: ### BubbleChartData
let data = BubbleChartData()
data.addDataSet(set)
chartView.data = data

chartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView
/*:
 ****
 [Menu](Menu)
 
 [Previous](@previous)
 ****
 */

