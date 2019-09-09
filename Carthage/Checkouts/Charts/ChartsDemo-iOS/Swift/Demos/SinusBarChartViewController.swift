//
//  SinusBarChartViewController.swift
//  ChartsDemo-iOS
//
//  Created by Jacob Christie on 2017-07-09.
//  Copyright © 2017 jc. All rights reserved.
//

import UIKit
import Charts

class SinusBarChartViewController: DemoBaseViewController {
    
    @IBOutlet var chartView: BarChartView!
    @IBOutlet var sliderX: UISlider!
    @IBOutlet var sliderTextX: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.title = "Sinus Bar Chart"
        self.options = [.toggleValues,
                        .toggleHighlight,
                        .animateX,
                        .animateY,
                        .animateXY,
                        .saveToGallery,
                        .togglePinchZoom,
                        .toggleAutoScaleMinMax,
                        .toggleData]
        
        chartView.delegate = self
        
        chartView.chartDescription?.enabled = false
        
        chartView.drawBarShadowEnabled = false
        chartView.drawValueAboveBarEnabled = false
        chartView.maxVisibleCount = 60
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.enabled = false
        
        let leftAxis = chartView.leftAxis
        leftAxis.labelCount = 6
        leftAxis.axisMinimum = -2.5
        leftAxis.axisMaximum = 2.5
        leftAxis.granularityEnabled = true
        leftAxis.granularity = 0.1
        
        let rightAxis = chartView.rightAxis
        rightAxis.labelCount = 6
        rightAxis.axisMinimum = -2.5
        rightAxis.axisMaximum = 2.5
        rightAxis.granularity = 0.1

        let l = chartView.legend
        l.horizontalAlignment = .left
        l.verticalAlignment = .bottom
        l.orientation = .horizontal
        l.drawInside = false
        l.form = .square
        l.formSize = 9
        l.font = .systemFont(ofSize: 11)
        l.xEntrySpace = 4
//        chartView.legend = l

        sliderX.value = 150
        slidersValueChanged(nil)
        
        chartView.animate(xAxisDuration: 2, yAxisDuration: 2)
    }
    
    override func updateChartData() {
        if self.shouldHideData {
            chartView.data = nil
            return
        }
        
        self.setDataCount(Int(sliderX.value))
    }
    
    func setDataCount(_ count: Int) {
        let entries = (0..<count).map {
            BarChartDataEntry(x: Double($0), y: sin(.pi * Double($0%128) / 64))
        }
        
        let set = BarChartDataSet(entries: entries, label: "Sinus Function")
        set.setColor(UIColor(red: 240/255, green: 120/255, blue: 123/255, alpha: 1))
        
        let data = BarChartData(dataSet: set)
        data.setValueFont(.systemFont(ofSize: 10, weight: .light))
        data.setDrawValues(false)
        data.barWidth = 0.8
        
        chartView.data = data
    }
    
    override func optionTapped(_ option: Option) {
        super.handleOption(option, forChartView: chartView)
    }
    
    @IBAction func slidersValueChanged(_ sender: Any?) {
        sliderTextX.text = "\(Int(sliderX.value))"
        self.updateChartData()
    }
}
