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

//: # Combined Chart
import Cocoa
import Charts
import PlaygroundSupport


func setChartData()
{
    let data = CombinedChartData()
    data.lineData = generateLineData()
    data.barData = generateBarData()
    chartView.xAxis.axisMaximum = data.xMax + 0.25
    chartView.data = data
}
//: ## function generateLineData
func generateLineData() -> LineChartData
{
//: ### ChartDataEntry
    var entries = [ChartDataEntry]()
    for index in 0..<ITEM_COUNT
    {
        entries.append(ChartDataEntry(x: Double(index) + 0.5, y: (Double(arc4random_uniform(15) + 5))))
    }
//: ### LineChartDataSet
    let set = LineChartDataSet(values: entries, label: "Line DataSet")
    set.colors = [#colorLiteral(red: 0.941176470588235, green: 0.933333333333333, blue: 0.274509803921569, alpha: 1.0)]
    set.lineWidth = 2.5
    set.circleColors = [#colorLiteral(red: 0.941176470588235, green: 0.933333333333333, blue: 0.274509803921569, alpha: 1.0)]
    set.circleHoleRadius = 2.5
    set.fillColor = #colorLiteral(red: 0.941176470588235, green: 0.933333333333333, blue: 0.274509803921569, alpha: 1.0)
    set.mode = .cubicBezier
    set.drawValuesEnabled = true
    set.valueFont = NSUIFont.systemFont(ofSize: CGFloat(10.0))
    set.valueTextColor = #colorLiteral(red: 0.941176470588235, green: 0.933333333333333, blue: 0.274509803921569, alpha: 1.0)
    set.axisDependency = .left
//: ### LineChartData
    let data = LineChartData()
    data.addDataSet(set)
    return data
}
//: ## function generateBarData
func generateBarData() -> BarChartData
{
//: ### BarChartDataEntry
    var entries1 = [BarChartDataEntry]()
    var entries2 = [BarChartDataEntry]()
    
    for _ in 0..<ITEM_COUNT
    {
        entries1.append(BarChartDataEntry(x: 0.0, y: (Double(arc4random_uniform(25) + 25))))
/*:
- Note: stacked
*/
        entries2.append(BarChartDataEntry(x: 0.0, yValues: [Double(arc4random_uniform(13) + 12), Double(arc4random_uniform(13) + 12)]))
    }
//: ### BarChartDataSet
    let set1            = BarChartDataSet(values: entries1, label: "Bar 1")
    set1.colors         = [#colorLiteral(red: 0.235294117647059, green: 0.862745098039216, blue: 0.305882352941176, alpha: 1.0)]
    set1.valueTextColor = #colorLiteral(red: 0.235294117647059, green: 0.862745098039216, blue: 0.305882352941176, alpha: 1.0)
    set1.valueFont      = NSUIFont.systemFont(ofSize: CGFloat(10.0))
    set1.axisDependency = .left
    
    let set2            = BarChartDataSet(values: entries2, label: "Bar 2")
    set2.stackLabels    = ["Stack 1", "Stack 2"]
    set2.colors         = [#colorLiteral(red: 0.23921568627451, green: 0.647058823529412, blue: 1.0, alpha: 1.0),  #colorLiteral(red: 0.090196078431373, green: 0.772549019607843, blue: 1.0, alpha: 1.0)]
    set2.valueTextColor = #colorLiteral(red: 0.23921568627451, green: 0.647058823529412, blue: 1.0, alpha: 1.0)
    set2.valueFont      = NSUIFont.systemFont(ofSize: CGFloat(10.0))
    set2.axisDependency = .left
//: ### BarChartData
    let groupSpace = 0.06
    let barSpace = 0.02
    let barWidth = 0.45
    
/*: 
- Note:  x2 dataset
(0.45 + 0.02) * 2 + 0.06 = 1.00 -> interval per "group"
 */
    let data = BarChartData(dataSets: [set1, set2])
    data.barWidth = barWidth
/*:
- Note: make this BarData object grouped
*/
    data.groupBars(fromX: 0.0, groupSpace: groupSpace, barSpace: barSpace)     // start at x = 0
    return data
}
//: ## Principal
let ITEM_COUNT  = 12


let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = CombinedChartView(frame: r)
//: ### General
chartView.drawGridBackgroundEnabled = false
chartView.drawBarShadowEnabled      = false
chartView.highlightFullBarEnabled   = false
chartView.drawOrder                 = [DrawOrder.bar.rawValue, DrawOrder.bubble.rawValue, DrawOrder.candle.rawValue, DrawOrder.line.rawValue, DrawOrder.scatter.rawValue]
//: ### xAxis
let xAxis                           = chartView.xAxis
xAxis.labelPosition                 = .bothSided
xAxis.axisMinimum                   = 0.0
xAxis.granularity                   = 1.0
//xAxis.valueFormatter                = BarChartFormatter()
//: ### LeftAxis
let leftAxis                        = chartView.leftAxis
leftAxis.drawGridLinesEnabled       = false
leftAxis.axisMinimum                = 0.0
//: ### RightAxis
let rightAxis                       = chartView.rightAxis
rightAxis.drawGridLinesEnabled      = false
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

setChartData()
chartView.animate(xAxisDuration: 2.0, yAxisDuration: 2.0, easingOption: .easeInBounce)

/*:---*/
//: ###  Setup for the live view
PlaygroundPage.current.liveView = chartView

/*:
 ****
 [Previous](@previous) | [Next](@next)
 */


