//
//  NegativeStackedBarChartViewController.swift
//  ChartsDemo-iOS
//
//  Created by Jacob Christie on 2017-07-09.
//  Copyright © 2017 jc. All rights reserved.
//

import UIKit
import Charts

class NegativeStackedBarChartViewController: DemoBaseViewController {

    @IBOutlet var chartView: HorizontalBarChartView!
    
    lazy var customFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.negativePrefix = ""
        formatter.positiveSuffix = "m"
        formatter.negativeSuffix = "m"
        formatter.minimumSignificantDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.title = "Stacked Bar Chart Negative"
        self.options = [.toggleValues,
                        .toggleIcons,
                        .toggleHighlight,
                        .animateX,
                        .animateY,
                        .animateXY,
                        .saveToGallery,
                        .togglePinchZoom,
                        .toggleAutoScaleMinMax,
                        .toggleData,
                        .toggleBarBorders]
        

        chartView.delegate = self
        
        chartView.chartDescription?.enabled = false
        
        chartView.drawBarShadowEnabled = false
        chartView.drawValueAboveBarEnabled = true
        
        chartView.leftAxis.enabled = false
        let rightAxis = chartView.rightAxis
        rightAxis.axisMaximum = 25
        rightAxis.axisMinimum = -25
        rightAxis.drawZeroLineEnabled = true
        rightAxis.labelCount = 7
        rightAxis.valueFormatter = DefaultAxisValueFormatter(formatter: customFormatter)
        rightAxis.labelFont = .systemFont(ofSize: 9)
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bothSided
        xAxis.drawAxisLineEnabled = false
        xAxis.axisMinimum = 0
        xAxis.axisMaximum = 110
        xAxis.centerAxisLabelsEnabled = true
        xAxis.labelCount = 12
        xAxis.granularity = 10
        xAxis.valueFormatter = self
        xAxis.labelFont = .systemFont(ofSize: 9)
        
        let l = chartView.legend
        l.horizontalAlignment = .right
        l.verticalAlignment = .bottom
        l.orientation = .horizontal
        l.formSize = 8
        l.formToTextSpace = 8
        l.xEntrySpace = 6
//        chartView.legend = l

        self.updateChartData()
    }
    
    override func updateChartData() {
        if self.shouldHideData {
            chartView.data = nil
            return
        }
        
        self.setChartData()
    }
    
    func setChartData() {
        let yVals = [BarChartDataEntry(x: 5, yValues: [-10, 10]),
                     BarChartDataEntry(x: 15, yValues: [-12, 13]),
                     BarChartDataEntry(x: 25, yValues: [-15, 15]),
                     BarChartDataEntry(x: 35, yValues: [-17, 17]),
                     BarChartDataEntry(x: 45, yValues: [-19, 120]),
                     BarChartDataEntry(x: 55, yValues: [-19, 19]),
                     BarChartDataEntry(x: 65, yValues: [-16, 16]),
                     BarChartDataEntry(x: 75, yValues: [-13, 14]),
                     BarChartDataEntry(x: 85, yValues: [-10, 11]),
                     BarChartDataEntry(x: 95, yValues: [-5, 6]),
                     BarChartDataEntry(x: 105, yValues: [-1, 2])
        ]
        
        let set = BarChartDataSet(entries: yVals, label: "Age Distribution")
        set.drawIconsEnabled = false
        set.valueFormatter = DefaultValueFormatter(formatter: customFormatter)
        set.valueFont = .systemFont(ofSize: 7)
        set.axisDependency = .right
        set.colors = [UIColor(red: 67/255, green: 67/255, blue: 72/255, alpha: 1),
                      UIColor(red: 124/255, green: 181/255, blue: 236/255, alpha: 1)
        ]
        set.stackLabels = ["Men", "Women"]
        
        let data = BarChartData(dataSet: set)
        data.barWidth = 8.5
        
        chartView.data = data
        chartView.setNeedsDisplay()
    }
    
    override func optionTapped(_ option: Option) {
        super.handleOption(option, forChartView: chartView)
    }
}

extension NegativeStackedBarChartViewController: IAxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return String(format: "%03.0f-%03.0f", value, value + 10)
    }
}
