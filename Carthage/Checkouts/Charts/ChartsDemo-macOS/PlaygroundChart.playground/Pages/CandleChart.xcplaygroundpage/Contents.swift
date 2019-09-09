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

//: # Candle Chart
import Cocoa
import Charts
import PlaygroundSupport


func randomFloatBetween(from: Float, to: Float)->Float
{
    return Float(arc4random_uniform( UInt32(to - from ))) + Float(from)
}


let ITEM_COUNT  = 20


let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = CandleStickChartView(frame: r)
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
leftAxis.axisMinimum                = 0.0
//: ### RightAxis
let rightAxis                       = chartView.rightAxis
rightAxis.drawGridLinesEnabled      = true
rightAxis.axisMinimum               = 0.0
//: ### Legend
let legend                          = chartView.legend
legend.wordWrapEnabled              = true
legend.horizontalAlignment          = .center
legend.verticalAlignment            = .bottom
legend.orientation                  = .horizontal
legend.drawInside                   = false
//: ### Description
chartView.chartDescription?.enabled = false
//: ### CandleChartDataEntry
var entries = [CandleChartDataEntry]()

for i in 0..<ITEM_COUNT
{
    let mult: Float = 50
    let val = randomFloatBetween(from: mult, to: mult + 40)
    let high = randomFloatBetween(from: 8, to: 17)
    let low: Float = randomFloatBetween(from: 8, to: 17)
    let open: Float = randomFloatBetween(from: 1, to: 7)
    let close: Float = randomFloatBetween(from: 1, to: 7)
    let even: Bool = i % 2 == 0
    
    entries.append(CandleChartDataEntry(x: Double(i), shadowH: Double(val + high), shadowL: Double(val - low), open: Double(even ? val + open : val - open), close: Double(even ? val - close : val + close)))
    }
//: ### CandleChartDataSet
let set = CandleChartDataSet(values: entries, label: "Candle DataSet")
set.colors = [#colorLiteral(red: 0.313725490196078, green: 0.313725490196078, blue: 0.313725490196078, alpha: 1.0)]

set.decreasingColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
set.shadowColor = NSColor.red
set.valueFont = NSUIFont.systemFont(ofSize: CGFloat(10.0))
set.drawValuesEnabled = true
set.shadowWidth = 0.7
//: ### CandleChartData
let data = CandleChartData()
data.addDataSet(set)
chartView.data = data
chartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView
/*:
 ****
 [Previous](@previous) | [Next](@next)
 */


