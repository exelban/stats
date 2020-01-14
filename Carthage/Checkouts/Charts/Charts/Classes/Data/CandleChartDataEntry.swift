//
//  CandleChartDataEntry.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 4/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation

public class CandleChartDataEntry: ChartDataEntry
{
    /// shadow-high value
    public var high = Double(0.0)
    
    /// shadow-low value
    public var low = Double(0.0)
    
    /// close value
    public var close = Double(0.0)
    
    /// open value
    public var open = Double(0.0)
    
    public required init()
    {
        super.init()
    }
    
    public init(xIndex: Int, shadowH: Double, shadowL: Double, open: Double, close: Double)
    {
        super.init(value: (shadowH + shadowL) / 2.0, xIndex: xIndex)
        
        self.high = shadowH
        self.low = shadowL
        self.open = open
        self.close = close
    }
    
    public init(xIndex: Int, shadowH: Double, shadowL: Double, open: Double, close: Double, data: AnyObject?)
    {
        super.init(value: (shadowH + shadowL) / 2.0, xIndex: xIndex, data: data)
        
        self.high = shadowH
        self.low = shadowL
        self.open = open
        self.close = close
    }
    
    /// - returns: the overall range (difference) between shadow-high and shadow-low.
    public var shadowRange: Double
    {
        return abs(high - low)
    }
    
    /// - returns: the body size (difference between open and close).
    public var bodyRange: Double
    {
        return abs(open - close)
    }
    
    /// the center value of the candle. (Middle value between high and low)
    public override var value: Double
    {
        get
        {
            return super.value
        }
        set
        {
            super.value = (high + low) / 2.0
        }
    }
    
    // MARK: NSCopying
    
    public override func copyWithZone(zone: NSZone) -> AnyObject
    {
        let copy = super.copyWithZone(zone) as! CandleChartDataEntry
        copy.high = high
        copy.high = low
        copy.high = open
        copy.high = close
        return copy
    }
}