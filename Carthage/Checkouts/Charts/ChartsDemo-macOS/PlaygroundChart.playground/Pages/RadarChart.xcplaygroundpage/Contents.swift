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

//: # Radar Chart
import Cocoa
import Charts
import PlaygroundSupport

let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = RadarChartView(frame: r)
//: ### General
chartView.backgroundColor = #colorLiteral(red: 0.2605174184, green: 0.2605243921, blue: 0.260520637, alpha: 1)
chartView.webLineWidth = 1.0
chartView.innerWebLineWidth = 1.0
chartView.webColor = NSUIColor.lightGray
chartView.innerWebColor = NSUIColor.lightGray
chartView.webAlpha = 1.0
//: ### xAxis
let xAxis = chartView.xAxis
xAxis.labelFont = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(9.0))!
xAxis.xOffset = 0.0
xAxis.yOffset = 0.0
xAxis.labelTextColor = NSUIColor.white
//: ### yAxis
let yAxis = chartView.yAxis
yAxis.labelFont = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(9.0))!
yAxis.labelCount = 5
yAxis.axisMinimum = 0.0
yAxis.axisMaximum = 80.0
yAxis.drawLabelsEnabled = false
//: ### Legend
let legend = chartView.legend
legend.horizontalAlignment = .center
legend.verticalAlignment = .top
legend.orientation = .horizontal
legend.drawInside = false
legend.font = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(10.0))!
legend.xEntrySpace = 7.0
legend.yEntrySpace = 5.0
legend.textColor = NSUIColor.white
//: ### Description
chartView.chartDescription?.enabled = true
chartView.chartDescription?.text = "Radar demo"
chartView.chartDescription?.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
//: ### RadarChartDataEntry
let mult = 80.0
let min = 20.0
let cnt = 5

var entries1 = [RadarChartDataEntry]()
var entries2 = [RadarChartDataEntry]()
/*:
- Note: The order of the entries when being added to the entries array determines their position around the center of the chart.
*/
for _ in 0..<cnt
{
    entries1.append(RadarChartDataEntry(value: (Double(arc4random_uniform(UInt32(mult))) + min)))
    entries2.append(RadarChartDataEntry(value: (Double(arc4random_uniform(UInt32(mult))) + min)))
}
//: ### RadarChartDataSet
let set1 = RadarChartDataSet(values: entries1, label: "Last Week")
set1.colors = [NSUIColor(red: CGFloat(103 / 255.0), green: CGFloat(110 / 255.0), blue: CGFloat(129 / 255.0), alpha: 1.0)]
set1.fillColor = NSUIColor(red: CGFloat(103 / 255.0), green: CGFloat(110 / 255.0), blue: CGFloat(129 / 255.0), alpha: 1.0)
set1.drawFilledEnabled = true
set1.fillAlpha = 0.7
set1.lineWidth = 2.0
set1.drawHighlightCircleEnabled = true
set1.setDrawHighlightIndicators(false)

let set2 = RadarChartDataSet(values: entries2, label: "This Week")
set2.colors = [NSUIColor(red: CGFloat(121 / 255.0), green: CGFloat(162 / 255.0), blue: CGFloat(175 / 255.0), alpha: 1.0)]
set2.fillColor = NSUIColor(red: CGFloat(121 / 255.0), green: CGFloat(162 / 255.0), blue: CGFloat(175 / 255.0), alpha: 1.0)
set2.drawFilledEnabled = true
set2.fillAlpha = 0.7
set2.lineWidth = 2.0
set2.drawHighlightCircleEnabled = true
set2.setDrawHighlightIndicators(false)
//: ### RadarChartData
let data = RadarChartData(dataSets: [set1, set2])
data.setValueFont ( NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(8.0)))
data.setDrawValues ( false )
data.setValueTextColor(  NSUIColor.white)
chartView.data = data

chartView.animate(xAxisDuration: 2.0, yAxisDuration: 2.0, easingOption: .easeInBounce)

/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView


/*:
 ****
 [Previous](@previous) | [Next](@next)
 */


