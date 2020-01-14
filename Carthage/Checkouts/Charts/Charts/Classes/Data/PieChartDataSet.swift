//
//  PieChartDataSet.swift
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
import CoreGraphics
import UIKit

public class PieChartDataSet: ChartDataSet
{
    private var _sliceSpace = CGFloat(0.0)
    
    /// indicates the selection distance of a pie slice
    public var selectionShift = CGFloat(18.0)
    
    public required init()
    {
        super.init()
        
        self.valueTextColor = UIColor.whiteColor()
        self.valueFont = UIFont.systemFontOfSize(13.0)
    }
    
    public override init(yVals: [ChartDataEntry]?, label: String?)
    {
        super.init(yVals: yVals, label: label)
        
        self.valueTextColor = UIColor.whiteColor()
        self.valueFont = UIFont.systemFontOfSize(13.0)
    }
    
    /// the space that is left out between the piechart-slices, default: 0°
    /// --> no space, maximum 45, minimum 0 (no space)
    public var sliceSpace: CGFloat
    {
        get
        {
            return _sliceSpace
        }
        set
        {
            _sliceSpace = newValue
            if (_sliceSpace > 45.0)
            {
                _sliceSpace = 45.0
            }
            if (_sliceSpace < 0.0)
            {
                _sliceSpace = 0.0
            }
        }
    }
    
    // MARK: NSCopying
    
    public override func copyWithZone(zone: NSZone) -> AnyObject
    {
        let copy = super.copyWithZone(zone) as! PieChartDataSet
        copy._sliceSpace = _sliceSpace
        copy.selectionShift = selectionShift
        return copy
    }
}