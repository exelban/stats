//
//  PieData.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 24/2/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation

public class PieChartData: ChartData
{
    public override init()
    {
        super.init()
    }
    
    public override init(xVals: [String?]?, dataSets: [ChartDataSet]?)
    {
        super.init(xVals: xVals, dataSets: dataSets)
    }

    public override init(xVals: [NSObject]?, dataSets: [ChartDataSet]?)
    {
        super.init(xVals: xVals, dataSets: dataSets)
    }

    var dataSet: PieChartDataSet?
    {
        get
        {
            return dataSets.count > 0 ? dataSets[0] as? PieChartDataSet : nil
        }
        set
        {
            if (newValue != nil)
            {
                dataSets = [newValue!]
            }
            else
            {
                dataSets = []
            }
        }
    }
    
    public override func getDataSetByIndex(index: Int) -> ChartDataSet?
    {
        if (index != 0)
        {
            return nil
        }
        return super.getDataSetByIndex(index)
    }
    
    public override func getDataSetByLabel(label: String, ignorecase: Bool) -> ChartDataSet?
    {
        if (dataSets.count == 0 || dataSets[0].label == nil)
        {
            return nil
        }
        
        if (ignorecase)
        {
            if (label.caseInsensitiveCompare(dataSets[0].label!) == NSComparisonResult.OrderedSame)
            {
                return dataSets[0]
            }
        }
        else
        {
            if (label == dataSets[0].label)
            {
                return dataSets[0]
            }
        }
        return nil
    }
}
