//
//  RadarDemoViewController.swift
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

open class RadarDemoViewController: NSViewController
{
    @IBOutlet var radarChartView: RadarChartView!
    
    override open func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        let ys1 = Array(1..<10).map { x in return sin(Double(x) / 2.0 / 3.141 * 1.5) }
        let ys2 = Array(1..<10).map { x in return cos(Double(x) / 2.0 / 3.141) }
        
        let yse1 = ys1.enumerated().map { x, y in return RadarChartDataEntry(value: y) }
        let yse2 = ys2.enumerated().map { x, y in return RadarChartDataEntry(value: y) }
        
        let data = RadarChartData()
        let ds1 = RadarChartDataSet(entries: yse1, label: "Hello")
        ds1.colors = [NSUIColor.red]
        data.addDataSet(ds1)
        
        let ds2 = RadarChartDataSet(entries: yse2, label: "World")
        ds2.colors = [NSUIColor.blue]
        data.addDataSet(ds2)
        self.radarChartView.data = data
        self.radarChartView.chartDescription?.text = "Radarchart Demo"

    }
    
    override open func viewWillAppear()
    {
        self.radarChartView.animate(xAxisDuration: 0.0, yAxisDuration: 1.0)
    }
}
