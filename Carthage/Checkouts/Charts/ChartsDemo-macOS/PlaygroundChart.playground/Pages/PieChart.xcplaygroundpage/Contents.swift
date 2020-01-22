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

//: # Pie Chart
import Cocoa
import Charts
import PlaygroundSupport


let r = CGRect(x: 0, y: 0, width: 600, height: 600)
var chartView = PieChartView(frame: r)
//: ### General
let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default().mutableCopy() as! NSMutableParagraphStyle
paragraphStyle.lineBreakMode = .byTruncatingTail
paragraphStyle.alignment = .center

let centerText: NSMutableAttributedString = NSMutableAttributedString(string: "Charts\nby Daniel Cohen Gindi")
centerText.setAttributes([NSFontAttributeName: NSUIFont(name: "HelveticaNeue-Light", size: 15.0)!, NSParagraphStyleAttributeName: paragraphStyle], range: NSMakeRange(0, centerText.length))
centerText.addAttributes([NSFontAttributeName: NSUIFont(name: "HelveticaNeue-Light", size: 13.0)!, NSForegroundColorAttributeName: NSUIColor.gray], range: NSMakeRange(10, centerText.length - 10))
centerText.addAttributes([NSFontAttributeName: NSUIFont(name: "HelveticaNeue-LightItalic", size: 13.0)!, NSForegroundColorAttributeName: NSUIColor(red: 51 / 255.0, green: 181 / 255.0, blue: 229 / 255.0, alpha: 1.0)], range: NSMakeRange(centerText.length - 19, 19))

chartView.centerAttributedText = centerText
chartView.chartDescription?.text = "Pie Chart"
//: ### PieChartDataEntry
let ys1 = Array(1..<10).map { x in return sin(Double(x) / 2.0 / 3.141 * 1.5) * 100.0 }
let yse1 = ys1.enumerated().map { x, y in return PieChartDataEntry(value: y, label: String(x)) }
//: ### PieChartDataSet
let ds1 = PieChartDataSet(values: yse1, label: "Hello")
ds1.colors = ChartColorTemplates.vordiplom()
//: ### PieChartData
let data = PieChartData()
data.addDataSet(ds1)
chartView.data = data

chartView.animate(xAxisDuration: 2.0, yAxisDuration: 2.0, easingOption: .easeInBounce)

/*:---*/
//: ### Setup for the live view
PlaygroundPage.current.liveView = chartView
/*:
 ****
 [Previous](@previous) | [Next](@next)
 */
