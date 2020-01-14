//
//  ChartRange.swift
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

public class ChartRange: NSObject
{
    public var from: Double
    public var to: Double
    
    public init(from: Double, to: Double)
    {
        self.from = from
        self.to = to
        
        super.init()
    }

    /// Returns true if this range contains (if the value is in between) the given value, false if not.
    /// - parameter value:
    public func contains(value: Double) -> Bool
    {
        if value > from && value <= to
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    public func isLarger(value: Double) -> Bool
    {
        return value > to
    }
    
    public func isSmaller(value: Double) -> Bool
    {
        return value < from
    }
}