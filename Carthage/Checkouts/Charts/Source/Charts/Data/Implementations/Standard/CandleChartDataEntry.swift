//
//  CandleChartDataEntry.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation

open class CandleChartDataEntry: ChartDataEntry
{
    /// shadow-high value
    @objc open var high = Double(0.0)
    
    /// shadow-low value
    @objc open var low = Double(0.0)
    
    /// close value
    @objc open var close = Double(0.0)
    
    /// open value
    @objc open var open = Double(0.0)
    
    public required init()
    {
        super.init()
    }
    
    @objc public init(x: Double, shadowH: Double, shadowL: Double, open: Double, close: Double)
    {
        super.init(x: x, y: (shadowH + shadowL) / 2.0)
        
        self.high = shadowH
        self.low = shadowL
        self.open = open
        self.close = close
    }

    @objc public convenience init(x: Double, shadowH: Double, shadowL: Double, open: Double, close: Double, icon: NSUIImage?)
    {
        self.init(x: x, shadowH: shadowH, shadowL: shadowL, open: open, close: close)
        self.icon = icon
    }

    @objc public convenience init(x: Double, shadowH: Double, shadowL: Double, open: Double, close: Double, data: Any?)
    {
        self.init(x: x, shadowH: shadowH, shadowL: shadowL, open: open, close: close)
        self.data = data
    }

    @objc public convenience init(x: Double, shadowH: Double, shadowL: Double, open: Double, close: Double, icon: NSUIImage?, data: Any?)
    {
        self.init(x: x, shadowH: shadowH, shadowL: shadowL, open: open, close: close)
        self.icon = icon
        self.data = data
    }
    
    /// The overall range (difference) between shadow-high and shadow-low.
    @objc open var shadowRange: Double
    {
        return abs(high - low)
    }
    
    /// The body size (difference between open and close).
    @objc open var bodyRange: Double
    {
        return abs(open - close)
    }
    
    /// the center value of the candle. (Middle value between high and low)
    open override var y: Double
    {
        get
        {
            return super.y
        }
        set
        {
            super.y = (high + low) / 2.0
        }
    }
    
    // MARK: NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any
    {
        let copy = super.copy(with: zone) as! CandleChartDataEntry
        copy.high = high
        copy.low = low
        copy.open = open
        copy.close = close
        return copy
    }
}
