//
//  RadarChartDataSet.swift
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
import UIKit

public class RadarChartDataSet: LineRadarChartDataSet
{
    public required init()
    {
        super.init()
        
        self.valueFont = UIFont.systemFontOfSize(13.0)
    }
    
    public override init(yVals: [ChartDataEntry]?, label: String?)
    {
        super.init(yVals: yVals, label: label)
        
        self.valueFont = UIFont.systemFontOfSize(13.0)
    }
}