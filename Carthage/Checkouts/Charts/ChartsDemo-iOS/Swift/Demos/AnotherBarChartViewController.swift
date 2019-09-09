//
//  AnotherBarChartViewController.swift
//  ChartsDemo-iOS
//
//  Created by Jacob Christie on 2017-07-09.
//  Copyright © 2017 jc. All rights reserved.
//

import UIKit
import Charts

class AnotherBarChartViewController: DemoBaseViewController {
    
    @IBOutlet var chartView: BarChartView!
    @IBOutlet var sliderX: UISlider!
    @IBOutlet var sliderY: UISlider!
    @IBOutlet var sliderTextX: UITextField!
    @IBOutlet var sliderTextY: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.title = "Another Bar Chart"
        
        self.options = [.toggleValues,
                        .toggleHighlight,
                        .animateX,
                        .animateY,
                        .animateXY,
                        .saveToGallery,
                        .togglePinchZoom,
                        .toggleData,
                        .toggleBarBorders]
        
        chartView.delegate = self
        
        chartView.chartDescription?.enabled = false
        chartView.maxVisibleCount = 60
        chartView.pinchZoomEnabled = false
        chartView.drawBarShadowEnabled = false
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
                
        chartView.legend.enabled = false
        
        sliderX.value = 10
        sliderY.value = 100
        self.slidersValueChanged(nil)
    }
    
    
    override func updateChartData() {
        if self.shouldHideData {
            chartView.data = nil
            return
        }
        
        self.setDataCount(Int(sliderX.value) + 1, range: Double(sliderY.value))
    }
    
    func setDataCount(_ count: Int, range: Double) {
        let yVals = (0..<count).map { (i) -> BarChartDataEntry in
            let mult = range + 1
            let val = Double(arc4random_uniform(UInt32(mult))) + mult/3
            return BarChartDataEntry(x: Double(i), y: val)
        }
        
        var set1: BarChartDataSet! = nil
        if let set = chartView.data?.dataSets.first as? BarChartDataSet {
            set1 = set
            set1?.replaceEntries(yVals)
            chartView.data?.notifyDataChanged()
            chartView.notifyDataSetChanged()
        } else {
            set1 = BarChartDataSet(entries: yVals, label: "Data Set")
            set1.colors = ChartColorTemplates.vordiplom()
            set1.drawValuesEnabled = false
            
            let data = BarChartData(dataSet: set1)
            chartView.data = data
            chartView.fitBars = true
        }
        
        chartView.setNeedsDisplay()
    }
    
    override func optionTapped(_ option: Option) {
        super.handleOption(option, forChartView: chartView)
    }
    
    // MARK: - Actions
    @IBAction func slidersValueChanged(_ sender: Any?) {
        sliderTextX.text = "\(Int(sliderX.value))"
        sliderTextY.text = "\(Int(sliderY.value))"
        
        self.updateChartData()
    }
}
