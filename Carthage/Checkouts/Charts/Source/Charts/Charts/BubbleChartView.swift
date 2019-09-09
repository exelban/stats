//
//  BubbleChartView.swift
//  Charts
//
//  Bubble chart implementation:
//    Copyright 2015 Pierre-Marc Airoldi
//    Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

open class BubbleChartView: BarLineChartViewBase, BubbleChartDataProvider
{
    open override func initialize()
    {
        super.initialize()
        
        renderer = BubbleChartRenderer(dataProvider: self, animator: _animator, viewPortHandler: _viewPortHandler)
    }
    
    // MARK: - BubbleChartDataProvider
    
    open var bubbleData: BubbleChartData? { return _data as? BubbleChartData }
}
