//
//  ChartDataFilter.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 23/2/15.

//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation

public class ChartDataBaseFilter: NSObject
{
    public override init()
    {
        super.init()
    }
    
    public func filter(points: [ChartDataEntry]) -> [ChartDataEntry]
    {
        fatalError("filter() cannot be called on ChartDataBaseFilter")
    }
}