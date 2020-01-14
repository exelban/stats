//
//  ScatterChartDataSet.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 26/2/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics

public class ScatterChartDataSet: LineScatterCandleChartDataSet
{
    @objc
    public enum ScatterShape: Int
    {
        case Cross
        case Triangle
        case Circle
        case Square
        case Custom
    }
    
    public var scatterShapeSize = CGFloat(15.0)
    public var scatterShape = ScatterShape.Square
    public var customScatterShape: CGPath?

    // MARK: NSCopying
    
    public override func copyWithZone(zone: NSZone) -> AnyObject
    {
        let copy = super.copyWithZone(zone) as! ScatterChartDataSet
        copy.scatterShapeSize = scatterShapeSize
        copy.scatterShape = scatterShape
        copy.customScatterShape = customScatterShape
        return copy
    }
}
