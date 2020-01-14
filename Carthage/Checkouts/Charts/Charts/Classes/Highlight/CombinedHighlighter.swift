//
//  CombinedHighlighter.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 26/7/15.

//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics

internal class CombinedHighlighter: ChartHighlighter
{
    internal init(chart: CombinedChartView)
    {
        super.init(chart: chart)
    }
    
    /// Returns a list of SelectionDetail object corresponding to the given xIndex.
    /// - parameter xIndex:
    /// - returns:
    internal override func getSelectionDetailsAtIndex(xIndex: Int) -> [ChartSelectionDetail]
    {
        var vals = [ChartSelectionDetail]()
        
        if let data = _chart?.data as? CombinedChartData
        {
            // get all chartdata objects
            var dataObjects = data.allData
            
            var pt = CGPoint()
            
            for var i = 0; i < dataObjects.count; i++
            {
                for var j = 0; j < dataObjects[i].dataSetCount; j++
                {
                    let dataSet = dataObjects[i].getDataSetByIndex(j)
                    
                    // dont include datasets that cannot be highlighted
                    if !dataSet.isHighlightEnabled
                    {
                        continue
                    }
                    
                    // extract all y-values from all DataSets at the given x-index
                    let yVal = dataSet.yValForXIndex(xIndex)
                    if yVal.isNaN
                    {
                        continue
                    }
                    
                    pt.y = CGFloat(yVal)
                    
                    _chart!.getTransformer(dataSet.axisDependency).pointValueToPixel(&pt)
                    
                    if !pt.y.isNaN
                    {
                        vals.append(ChartSelectionDetail(value: Double(pt.y), dataSetIndex: j, dataSet: dataSet))
                    }
                }
            }
        }
        
        return vals
    }
}
