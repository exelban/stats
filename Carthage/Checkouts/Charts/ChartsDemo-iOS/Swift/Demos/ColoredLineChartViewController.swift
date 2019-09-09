//
//  ColoredLineChartViewController.swift
//  ChartsDemo-iOS
//
//  Created by Jacob Christie on 2017-07-04.
//  Copyright © 2017 jc. All rights reserved.
//

import UIKit
import Charts

class ColoredLineChartViewController: DemoBaseViewController {
    @IBOutlet var chartViews: [LineChartView]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Colored Line Chart"
        
        let colors = [UIColor(red: 137/255, green: 230/255, blue: 81/255, alpha: 1),
                      UIColor(red: 240/255, green: 240/255, blue: 30/255, alpha: 1),
                      UIColor(red: 89/255, green: 199/255, blue: 250/255, alpha: 1),
                      UIColor(red: 250/255, green: 104/255, blue: 104/255, alpha: 1)]
        
        for (i, chartView) in chartViews.enumerated() {
            let data = dataWithCount(36, range: 100)
            data.setValueFont(UIFont(name: "HelveticaNeue", size: 7)!)
            
            setupChart(chartView, data: data, color: colors[i % colors.count])
        }
    }
    
    func setupChart(_ chart: LineChartView, data: LineChartData, color: UIColor) {
        (data.getDataSetByIndex(0) as! LineChartDataSet).circleHoleColor = color
        
        chart.delegate = self
        chart.backgroundColor = color
        
        chart.chartDescription?.enabled = false
        
        chart.dragEnabled = true
        chart.setScaleEnabled(true)
        chart.pinchZoomEnabled = false
        chart.setViewPortOffsets(left: 10, top: 0, right: 10, bottom: 0)
        
        chart.legend.enabled = false
        
        chart.leftAxis.enabled = false
        chart.leftAxis.spaceTop = 0.4
        chart.leftAxis.spaceBottom = 0.4
        chart.rightAxis.enabled = false
        chart.xAxis.enabled = false
        
        chart.data = data
        
        chart.animate(xAxisDuration: 2.5)
    }
    
    func dataWithCount(_ count: Int, range: UInt32) -> LineChartData {
        let yVals = (0..<count).map { i -> ChartDataEntry in
            let val = Double(arc4random_uniform(range)) + 3
            return ChartDataEntry(x: Double(i), y: val)
        }
        
        let set1 = LineChartDataSet(entries: yVals, label: "DataSet 1")
        
        set1.lineWidth = 1.75
        set1.circleRadius = 5.0
        set1.circleHoleRadius = 2.5
        set1.setColor(.white)
        set1.setCircleColor(.white)
        set1.highlightColor = .white
        set1.drawValuesEnabled = false
        
        return LineChartData(dataSet: set1)
    }
}
