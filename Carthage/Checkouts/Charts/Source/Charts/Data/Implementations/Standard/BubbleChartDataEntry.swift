//
//  BubbleDataEntry.swift
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

open class BubbleChartDataEntry: ChartDataEntry
{
    /// The size of the bubble.
    @objc open var size = CGFloat(0.0)
    
    public required init()
    {
        super.init()
    }
    
    /// - Parameters:
    ///   - x: The index on the x-axis.
    ///   - y: The value on the y-axis.
    ///   - size: The size of the bubble.
    @objc public init(x: Double, y: Double, size: CGFloat)
    {
        super.init(x: x, y: y)
        
        self.size = size
    }
    
    /// - Parameters:
    ///   - x: The index on the x-axis.
    ///   - y: The value on the y-axis.
    ///   - size: The size of the bubble.
    ///   - data: Spot for additional data this Entry represents.
    @objc public convenience init(x: Double, y: Double, size: CGFloat, data: Any?)
    {
        self.init(x: x, y: y, size: size)
        self.data = data
    }
    
    /// - Parameters:
    ///   - x: The index on the x-axis.
    ///   - y: The value on the y-axis.
    ///   - size: The size of the bubble.
    ///   - icon: icon image
    @objc public convenience init(x: Double, y: Double, size: CGFloat, icon: NSUIImage?)
    {
        self.init(x: x, y: y, size: size)
        self.icon = icon
    }
    
    /// - Parameters:
    ///   - x: The index on the x-axis.
    ///   - y: The value on the y-axis.
    ///   - size: The size of the bubble.
    ///   - icon: icon image
    ///   - data: Spot for additional data this Entry represents.
    @objc public convenience init(x: Double, y: Double, size: CGFloat, icon: NSUIImage?, data: Any?)
    {
        self.init(x: x, y: y, size: size)
        self.icon = icon
        self.data = data
    }
    
    // MARK: NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any
    {
        let copy = super.copy(with: zone) as! BubbleChartDataEntry
        copy.size = size
        return copy
    }
}
