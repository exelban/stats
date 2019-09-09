//
//  PieDemoViewController.swift
//  ChartsDemo-OSX
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts

import Foundation
import Cocoa
import Charts

open class PieDemoViewController: NSViewController
{
    @IBOutlet var pieChartView: PieChartView!
    
    override open func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        let ys1 = Array(1..<10).map { x in return sin(Double(x) / 2.0 / 3.141 * 1.5) * 100.0 }
        
        let yse1 = ys1.enumerated().map { x, y in return PieChartDataEntry(value: y, label: String(x)) }
        
        let data = PieChartData()
        let ds1 = PieChartDataSet(entries: yse1, label: "Hello")
        
        ds1.colors = ChartColorTemplates.vordiplom()
        
        data.addDataSet(ds1)
        
        let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        let centerText: NSMutableAttributedString = NSMutableAttributedString(string: "Charts\nby Daniel Cohen Gindi")
        centerText.setAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-Light", size: 15.0)!, NSAttributedString.Key.paragraphStyle: paragraphStyle], range: NSMakeRange(0, centerText.length))
        centerText.addAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-Light", size: 13.0)!, NSAttributedString.Key.foregroundColor: NSColor.gray], range: NSMakeRange(10, centerText.length - 10))
        centerText.addAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-LightItalic", size: 13.0)!, NSAttributedString.Key.foregroundColor: NSColor(red: 51 / 255.0, green: 181 / 255.0, blue: 229 / 255.0, alpha: 1.0)], range: NSMakeRange(centerText.length - 19, 19))
        
        self.pieChartView.centerAttributedText = centerText
        
        self.pieChartView.data = data
        
        self.pieChartView.chartDescription?.text = "Piechart Demo"
    }
    
    override open func viewWillAppear()
    {
        self.pieChartView.animate(xAxisDuration: 0.0, yAxisDuration: 1.0)
    }
}
