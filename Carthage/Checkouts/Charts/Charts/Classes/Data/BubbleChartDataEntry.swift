//
//  BubbleDataEntry.swift
//  Charts
//
//  Bubble chart implementation: 
//    Copyright 2015 Pierre-Marc Airoldi
//    Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics

public class BubbleChartDataEntry: ChartDataEntry
{
    /// The size of the bubble.
    public var size = CGFloat(0.0)
    
    public required init()
    {
        super.init()
    }
    
    /// - parameter xIndex: The index on the x-axis.
    /// - parameter val: The value on the y-axis.
    /// - parameter size: The size of the bubble.
    public init(xIndex: Int, value: Double, size: CGFloat)
    {
        super.init(value: value, xIndex: xIndex)
        
        self.size = size
    }
    
    /// - parameter xIndex: The index on the x-axis.
    /// - parameter val: The value on the y-axis.
    /// - parameter size: The size of the bubble.
    /// - parameter data: Spot for additional data this Entry represents.
    public init(xIndex: Int, value: Double, size: CGFloat, data: AnyObject?)
    {
        super.init(value: value, xIndex: xIndex, data: data)
      
        self.size = size
    }
    
    // MARK: NSCopying
    
    public override func copyWithZone(zone: NSZone) -> AnyObject
    {
        let copy = super.copyWithZone(zone) as! BubbleChartDataEntry
        copy.size = size
        return copy
    }
}