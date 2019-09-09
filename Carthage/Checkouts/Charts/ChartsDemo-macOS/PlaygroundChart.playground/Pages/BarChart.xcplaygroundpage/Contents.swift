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

//: # Bar Chart
//#-hidden-code
import Cocoa
import Charts
import PlaygroundSupport
//#-end-hidden-code


let months = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
let values : [Double] = [28800, 32400, 36000, 34000, 30000, 42000, 45000]

let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = BarChartView(frame: r)
//: ### General
chartView.pinchZoomEnabled          = false
chartView.drawBarShadowEnabled      = false
chartView.doubleTapToZoomEnabled    = false
chartView.drawGridBackgroundEnabled = true
chartView.fitBars                   = true
//: ### BarChartDataEntry
var yVals = [BarChartDataEntry]()
for i in 0..<7
{
    yVals.append(BarChartDataEntry(x: Double(i), y: values[i]))
}
//: ### BarChartDataSet
var set1 = BarChartDataSet()
set1 = BarChartDataSet(values: yVals, label: "DataSet")
set1.colors = ChartColorTemplates.vordiplom()
set1.drawValuesEnabled = true

var dataSets = [ChartDataSet]()
dataSets.append(set1)
//: ### BarChartData
let data = BarChartData(dataSets: dataSets)
chartView.data = data

chartView.animate(xAxisDuration: 2.0, yAxisDuration: 2.0, easingOption: .easeInBounce)
/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView
/*:
 ****
 [Previous](@previous) | [Next](@next)
 */
